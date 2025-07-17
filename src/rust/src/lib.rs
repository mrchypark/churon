use extendr_api::prelude::*;
use ort::{
	environment::Environment,
	ExecutionProvider, GraphOptimizationLevel,
	LoggingLevel, SessionBuilder, Session, Value,
};
use std::path::Path;
use std::fmt;
use ndarray::{ArrayD, IxDyn};
use std::collections::HashMap;

/// Tensor information structure containing metadata about model inputs/outputs
#[derive(Debug, Clone)]
#[extendr]
pub struct TensorInfo {
    /// Name of the tensor
    pub name: String,
    /// Shape of the tensor (dimensions)
    pub shape: Vec<i32>,
    /// Data type of the tensor
    pub data_type: String,
}

#[extendr]
impl TensorInfo {
    /// Create a new TensorInfo instance
    pub fn new(name: String, shape: Vec<i32>, data_type: String) -> Self {
        TensorInfo {
            name,
            shape,
            data_type,
        }
    }
    
    /// Get the tensor name
    pub fn get_name(&self) -> String {
        self.name.clone()
    }
    
    /// Get the tensor shape
    pub fn get_shape(&self) -> Vec<i32> {
        self.shape.clone()
    }
    
    /// Get the tensor data type
    pub fn get_data_type(&self) -> String {
        self.data_type.clone()
    }
}

/// Custom error types for churon package
#[derive(Debug, Clone)]
pub enum ChurOnError {
    /// Model loading related errors
    ModelLoad(String),
    /// Inference execution errors
    Inference(String),
    /// Data conversion errors between R and Rust
    DataConversion(String),
    /// Input data validation errors
    Validation(String),
    /// Execution provider related errors
    Provider(String),
}

impl fmt::Display for ChurOnError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ChurOnError::ModelLoad(msg) => write!(f, "Model load error: {}", msg),
            ChurOnError::Inference(msg) => write!(f, "Inference error: {}", msg),
            ChurOnError::DataConversion(msg) => write!(f, "Data conversion error: {}", msg),
            ChurOnError::Validation(msg) => write!(f, "Validation error: {}", msg),
            ChurOnError::Provider(msg) => write!(f, "Provider error: {}", msg),
        }
    }
}

impl std::error::Error for ChurOnError {}

/// Convert ChurOnError to extendr_api::Error for R integration
impl From<ChurOnError> for extendr_api::Error {
    fn from(err: ChurOnError) -> Self {
        match err {
            ChurOnError::ModelLoad(msg) => {
                extendr_api::Error::EvalError(format!("Model load failed: {}", msg).into())
            },
            ChurOnError::Inference(msg) => {
                extendr_api::Error::EvalError(format!("Inference failed: {}", msg).into())
            },
            ChurOnError::DataConversion(msg) => {
                extendr_api::Error::EvalError(format!("Data conversion failed: {}", msg).into())
            },
            ChurOnError::Validation(msg) => {
                extendr_api::Error::EvalError(format!("Input validation failed: {}", msg).into())
            },
            ChurOnError::Provider(msg) => {
                extendr_api::Error::EvalError(format!("Execution provider error: {}", msg).into())
            },
        }
    }
}

/// Type alias for Result with ChurOnError
pub type ChurOnResult<T> = std::result::Result<T, ChurOnError>;

struct RSession {
    pub session: Session,
    pub input_names: Vec<String>,
    pub output_names: Vec<String>,
    pub input_shapes: Vec<Vec<i64>>,
    pub output_shapes: Vec<Vec<i64>>,
    pub providers: Vec<String>,
    pub model_path: String,
    // Performance optimization: cache tensor info to avoid repeated allocations
    input_info_cache: Option<Vec<TensorInfo>>,
    output_info_cache: Option<Vec<TensorInfo>>,
}

#[extendr]
impl RSession {
    pub fn from_path(path: &str) -> extendr_api::Result<Self> {
        Self::from_path_with_providers_internal(path, None)
    }
    
    pub fn check_input(&self) {
        println!("Input names: {:?}", &self.input_names);
        println!("Input shapes: {:?}", &self.input_shapes);
    }
    
    /// Get input tensor information
    pub fn get_input_info(&self) -> List {
        let tensor_infos: Vec<TensorInfo> = self.session.inputs.iter()
            .enumerate()
            .map(|(i, input)| {
                let shape_i64 = self.input_shapes.get(i).cloned().unwrap_or_default();
                let shape_i32: Vec<i32> = shape_i64.iter().map(|&x| x as i32).collect();
                let data_type = format!("{:?}", input.input_type);
                TensorInfo::new(input.name.clone(), shape_i32, data_type)
            })
            .collect();
        
        List::from_values(tensor_infos)
    }
    
    /// Get output tensor information
    pub fn get_output_info(&self) -> List {
        let tensor_infos: Vec<TensorInfo> = self.session.outputs.iter()
            .enumerate()
            .map(|(i, output)| {
                let shape_i64 = self.output_shapes.get(i).cloned().unwrap_or_default();
                let shape_i32: Vec<i32> = shape_i64.iter().map(|&x| x as i32).collect();
                let data_type = format!("{:?}", output.output_type);
                TensorInfo::new(output.name.clone(), shape_i32, data_type)
            })
            .collect();
        
        List::from_values(tensor_infos)
    }
    
    /// Get current execution providers
    pub fn get_providers(&self) -> Vec<String> {
        self.providers.clone()
    }
    
    /// Get model path
    pub fn get_model_path(&self) -> String {
        self.model_path.clone()
    }
    
    /// Run inference with input data
    pub fn run(&self, inputs: List) -> extendr_api::Result<List> {
        // Validate session state
        self.validate_session()?;
        
        // Validate input data structure and names
        self.validate_inputs(&inputs)?;
        
        // Convert R inputs to HashMap of ndarray
        let input_tensors = self.prepare_input_tensors(inputs)?;
        
        // Convert ndarray to ort::Value
        let ort_inputs = self.convert_to_ort_values(input_tensors)?;
        
        // Run inference
        let outputs = self.session.run(ort_inputs)
            .map_err(|e| ChurOnError::Inference(format!("Inference execution failed: {}", e)))?;
        
        // Convert outputs back to R data structures
        self.convert_outputs_to_r(outputs)
    }
}

impl RSession {
    /// Validate session state before operations
    fn validate_session(&self) -> ChurOnResult<()> {
        if self.input_names.is_empty() {
            return Err(ChurOnError::Validation(
                "Session has no input tensors defined".to_string()
            ));
        }
        
        if self.output_names.is_empty() {
            return Err(ChurOnError::Validation(
                "Session has no output tensors defined".to_string()
            ));
        }
        
        if self.model_path.is_empty() {
            return Err(ChurOnError::Validation(
                "Session has no model path defined".to_string()
            ));
        }
        
        Ok(())
    }
    
    /// Validate input data structure and names
    fn validate_inputs(&self, inputs: &List) -> ChurOnResult<()> {
        // Check if inputs is empty
        if inputs.len() == 0 {
            return Err(ChurOnError::Validation(
                "No input data provided".to_string()
            ));
        }
        
        // Check if inputs have names
        let input_names = inputs.names().unwrap_or_default();
        if input_names.len() == 0 {
            return Err(ChurOnError::Validation(
                "Input data must be a named list".to_string()
            ));
        }
        
        // Collect input names into a vector for reuse
        let provided_input_names: Vec<String> = input_names.map(|name| name.to_string()).collect();
        
        // Check if all required inputs are provided
        for required_input in &self.input_names {
            if !provided_input_names.contains(required_input) {
                return Err(ChurOnError::Validation(
                    format!("Required input '{}' not provided", required_input)
                ));
            }
        }
        
        // Check for unexpected inputs
        for provided_name in &provided_input_names {
            if !self.input_names.contains(provided_name) {
                return Err(ChurOnError::Validation(
                    format!("Unexpected input '{}' provided. Expected inputs: {:?}", 
                           provided_name, self.input_names)
                ));
            }
        }
        
        Ok(())
    }
    
    /// Prepare input tensors from R List
    fn prepare_input_tensors(&self, inputs: List) -> ChurOnResult<HashMap<String, ArrayD<f32>>> {
        let mut input_tensors = HashMap::new();
        
        // Get input names from the list
        let input_names = inputs.names().unwrap_or_default();
        
        for (i, input_name) in input_names.enumerate() {
            let input_name_str = input_name;
            
            // Get the R object for this input
            let input_robj = inputs.index(i).unwrap();
            
            // Get expected shape for this input
            let expected_shape = if let Some(idx) = self.input_names.iter().position(|x| x == input_name_str) {
                self.input_shapes.get(idx).cloned().unwrap_or_default()
            } else {
                return Err(ChurOnError::Validation(format!("Unknown input name: {}", input_name_str)));
            };
            
            // Convert expected shape from i64 to usize
            let shape_usize: Vec<usize> = expected_shape.iter()
                .map(|&x| if x == -1 { 1 } else { x as usize })
                .collect();
            
            // Convert R data to ndarray
            let tensor = if let Ok(doubles) = Doubles::try_from(&input_robj) {
                DataConverter::r_to_ndarray_f32(doubles, &shape_usize)?
            } else {
                return Err(ChurOnError::DataConversion(
                    format!("Failed to convert input '{}' to numeric data", input_name_str)
                ));
            };
            
            input_tensors.insert(input_name_str.to_string(), tensor);
        }
        
        Ok(input_tensors)
    }
    
    /// Convert ndarray tensors to ort::Value
    fn convert_to_ort_values(&self, _tensors: HashMap<String, ArrayD<f32>>) -> ChurOnResult<Vec<Value>> {
        // TODO: Implement proper conversion from ndarray to ort::Value
        // This is a placeholder implementation due to complex ort API requirements
        return Err(ChurOnError::DataConversion(
            "Tensor conversion not yet implemented".to_string()
        ));
    }
    
    /// Convert ort output values back to R data structures
    fn convert_outputs_to_r(&self, outputs: Vec<Value>) -> extendr_api::Result<List> {
        let mut r_outputs = Vec::new();
        let mut output_names = Vec::new();
        
        for (i, output) in outputs.iter().enumerate() {
            let output_name = self.output_names.get(i)
                .cloned()
                .unwrap_or_else(|| format!("output_{}", i));
            
            // Extract data from ort::Value
            let r_data = match output.try_extract::<f32>() {
                Ok(tensor) => {
                    let array = tensor.view().to_owned();
                    let converted = DataConverter::ndarray_f32_to_r(array)
                        .map_err(|e| ChurOnError::DataConversion(format!("Failed to convert output: {}", e)))?;
                    converted.into_robj()
                },
                Err(_) => {
                    // Try other data types if f32 fails
                    match output.try_extract::<f64>() {
                        Ok(tensor) => {
                            let array = tensor.view().to_owned();
                            let converted = DataConverter::ndarray_f64_to_r(array)
                                .map_err(|e| ChurOnError::DataConversion(format!("Failed to convert output: {}", e)))?;
                            converted.into_robj()
                        },
                        Err(_) => {
                            return Err(ChurOnError::DataConversion(
                                format!("Unsupported output data type for '{}'", output_name)
                            ).into());
                        }
                    }
                }
            };
            
            r_outputs.push(r_data);
            output_names.push(output_name);
        }
        
        // Create named list
        let mut result = List::from_values(r_outputs);
        result.set_names(output_names)?;
        
        Ok(result)
    }
}

impl RSession {
    /// Internal method for creating RSession with optional providers
    fn from_path_with_providers_internal(path: &str, providers: Option<Vec<String>>) -> extendr_api::Result<Self> {
        // Create ONNX Runtime environment
        let environment = Environment::builder()
            .with_name("churon")
            .with_log_level(LoggingLevel::Warning)
            .build()
            .map_err(|e| ChurOnError::ModelLoad(format!("Failed to build environment: {}", e)))?;

        let environment = environment.into_arc();

        // Determine execution providers to use
        let execution_providers = Self::get_execution_providers(providers)?;
        
        // Build session with execution providers
        let session = SessionBuilder::new(&environment)
            .map_err(|e| ChurOnError::ModelLoad(format!("Failed to create session builder: {}", e)))?
            .with_optimization_level(GraphOptimizationLevel::Level1)
            .map_err(|e| ChurOnError::ModelLoad(format!("Failed to set optimization level: {}", e)))?
            .with_intra_threads(1)
            .map_err(|e| ChurOnError::ModelLoad(format!("Failed to set intra threads: {}", e)))?
            .with_execution_providers(execution_providers)
            .map_err(|e| ChurOnError::Provider(format!("Failed to set execution providers: {}", e)))?
            .with_model_from_file(Path::new(path))
            .map_err(|e| ChurOnError::ModelLoad(format!("Failed to load model from {}: {}", path, e)))?;

        // Extract input and output metadata
        let input_names: Vec<String> = session.inputs.iter()
            .map(|input| input.name.clone())
            .collect();
        
        let output_names: Vec<String> = session.outputs.iter()
            .map(|output| output.name.clone())
            .collect();
        
        let input_shapes: Vec<Vec<i64>> = session.inputs.iter()
            .map(|input| {
                input.dimensions.iter()
                    .map(|dim| dim.map(|d| d as i64).unwrap_or(-1))
                    .collect()
            })
            .collect();
        
        let output_shapes: Vec<Vec<i64>> = session.outputs.iter()
            .map(|output| {
                output.dimensions.iter()
                    .map(|dim| dim.map(|d| d as i64).unwrap_or(-1))
                    .collect()
            })
            .collect();

        // Get the actual providers used by the session
        let used_providers = Self::extract_used_providers(&session);

        Ok(RSession {
            session,
            input_names,
            output_names,
            input_shapes,
            output_shapes,
            providers: used_providers,
            model_path: path.to_string(),
        })
    }
}

impl RSession {
    /// Determine execution providers to use based on input or defaults
    fn get_execution_providers(providers: Option<Vec<String>>) -> ChurOnResult<Vec<ExecutionProvider>> {
        match providers {
            Some(provider_names) => {
                let mut execution_providers = Vec::new();
                
                for provider_name in provider_names {
                    match provider_name.to_lowercase().as_str() {
                        "cuda" => execution_providers.push(ExecutionProvider::CUDA(Default::default())),
                        "tensorrt" => execution_providers.push(ExecutionProvider::TensorRT(Default::default())),
                        "directml" => execution_providers.push(ExecutionProvider::DirectML(Default::default())),
                        "onednn" => execution_providers.push(ExecutionProvider::OneDNN(Default::default())),
                        "coreml" => execution_providers.push(ExecutionProvider::CoreML(Default::default())),
                        "cpu" => execution_providers.push(ExecutionProvider::CPU(Default::default())),
                        _ => return Err(ChurOnError::Provider(format!("Unknown execution provider: {}", provider_name))),
                    }
                }
                
                // Always add CPU as fallback if not already present
                if !execution_providers.iter().any(|ep| matches!(ep, ExecutionProvider::CPU(_))) {
                    execution_providers.push(ExecutionProvider::CPU(Default::default()));
                }
                
                Ok(execution_providers)
            },
            None => {
                // Default providers with fallback priority
                Ok(vec![
                    ExecutionProvider::CUDA(Default::default()),
                    ExecutionProvider::TensorRT(Default::default()),
                    ExecutionProvider::DirectML(Default::default()),
                    ExecutionProvider::OneDNN(Default::default()),
                    ExecutionProvider::CoreML(Default::default()),
                    ExecutionProvider::CPU(Default::default())
                ])
            }
        }
    }
    
    /// Extract the actual providers used by the session
    fn extract_used_providers(_session: &Session) -> Vec<String> {
        // This is a simplified implementation
        // In a real implementation, you would query the session for actual providers
        // For now, we'll return a default set indicating what might be available
        vec!["CPU".to_string()]
    }
}

/// Data conversion utilities for R-Rust interoperability
pub struct DataConverter;

impl DataConverter {
    /// Convert R numeric vector to ndarray f32
    pub fn r_to_ndarray_f32(r_data: Doubles, shape: &[usize]) -> ChurOnResult<ArrayD<f32>> {
        let data: Vec<f32> = r_data.iter()
            .map(|x| x.0 as f32)
            .collect();
        
        let total_elements: usize = shape.iter().product();
        if data.len() != total_elements {
            return Err(ChurOnError::DataConversion(
                format!("Data length {} doesn't match shape {:?} (expected {})", 
                       data.len(), shape, total_elements)
            ));
        }
        
        ArrayD::from_shape_vec(IxDyn(shape), data)
            .map_err(|e| ChurOnError::DataConversion(format!("Failed to create ndarray: {}", e)))
    }
    
    /// Convert R numeric vector to ndarray f64
    pub fn r_to_ndarray_f64(r_data: Doubles, shape: &[usize]) -> ChurOnResult<ArrayD<f64>> {
        let data: Vec<f64> = r_data.iter().map(|x| x.0 as f64).collect();
        
        let total_elements: usize = shape.iter().product();
        if data.len() != total_elements {
            return Err(ChurOnError::DataConversion(
                format!("Data length {} doesn't match shape {:?} (expected {})", 
                       data.len(), shape, total_elements)
            ));
        }
        
        ArrayD::from_shape_vec(IxDyn(shape), data)
            .map_err(|e| ChurOnError::DataConversion(format!("Failed to create ndarray: {}", e)))
    }
    
    /// Convert R integer vector to ndarray i32
    pub fn r_to_ndarray_i32(r_data: Integers, shape: &[usize]) -> ChurOnResult<ArrayD<i32>> {
        let data: Vec<i32> = r_data.iter().map(|x| x.0 as i32).collect();
        
        let total_elements: usize = shape.iter().product();
        if data.len() != total_elements {
            return Err(ChurOnError::DataConversion(
                format!("Data length {} doesn't match shape {:?} (expected {})", 
                       data.len(), shape, total_elements)
            ));
        }
        
        ArrayD::from_shape_vec(IxDyn(shape), data)
            .map_err(|e| ChurOnError::DataConversion(format!("Failed to create ndarray: {}", e)))
    }
    
    /// Convert R integer vector to ndarray i64
    pub fn r_to_ndarray_i64(r_data: Integers, shape: &[usize]) -> ChurOnResult<ArrayD<i64>> {
        let data: Vec<i64> = r_data.iter()
            .map(|x| x.0 as i64)
            .collect();
        
        let total_elements: usize = shape.iter().product();
        if data.len() != total_elements {
            return Err(ChurOnError::DataConversion(
                format!("Data length {} doesn't match shape {:?} (expected {})", 
                       data.len(), shape, total_elements)
            ));
        }
        
        ArrayD::from_shape_vec(IxDyn(shape), data)
            .map_err(|e| ChurOnError::DataConversion(format!("Failed to create ndarray: {}", e)))
    }
    
    /// Convert ndarray f32 to R numeric vector
    pub fn ndarray_f32_to_r(array: ArrayD<f32>) -> ChurOnResult<Doubles> {
        let data: Vec<f64> = array.iter()
            .map(|&x| x as f64)
            .collect();
        
        Ok(Doubles::from_values(data))
    }
    
    /// Convert ndarray f64 to R numeric vector
    pub fn ndarray_f64_to_r(array: ArrayD<f64>) -> ChurOnResult<Doubles> {
        let data: Vec<f64> = array.iter().cloned().collect();
        Ok(Doubles::from_values(data))
    }
    
    /// Convert ndarray i32 to R integer vector
    pub fn ndarray_i32_to_r(array: ArrayD<i32>) -> ChurOnResult<Integers> {
        let data: Vec<i32> = array.iter().cloned().collect();
        Ok(Integers::from_values(data))
    }
    
    /// Convert ndarray i64 to R integer vector
    pub fn ndarray_i64_to_r(array: ArrayD<i64>) -> ChurOnResult<Integers> {
        let data: Vec<i32> = array.iter()
            .map(|&x| x as i32)
            .collect();
        Ok(Integers::from_values(data))
    }
    
    /// Validate input data against expected tensor info
    pub fn validate_input_data(
        data_shape: &[usize], 
        expected_info: &TensorInfo
    ) -> ChurOnResult<()> {
        // Convert expected shape from i32 to usize for comparison
        let expected_shape: Vec<usize> = expected_info.shape.iter()
            .map(|&x| if x == -1 { 0 } else { x as usize })
            .collect();
        
        // Check if shapes are compatible (allowing for dynamic dimensions marked as -1)
        if data_shape.len() != expected_shape.len() {
            return Err(ChurOnError::Validation(
                format!("Shape dimension mismatch: got {} dimensions, expected {}", 
                       data_shape.len(), expected_shape.len())
            ));
        }
        
        for (i, (&actual, &expected)) in data_shape.iter().zip(expected_shape.iter()).enumerate() {
            if expected != 0 && actual != expected {
                return Err(ChurOnError::Validation(
                    format!("Shape mismatch at dimension {}: got {}, expected {}", 
                           i, actual, expected)
                ));
            }
        }
        
        Ok(())
    }
    
    /// Get shape from R array/matrix
    pub fn get_r_array_shape(robj: &Robj) -> ChurOnResult<Vec<usize>> {
        if let Some(dims) = robj.dim() {
            Ok(dims.iter().map(|x| x.0 as usize).collect())
        } else {
            // For vectors, return length as single dimension
            Ok(vec![robj.len()])
        }
    }
}

extendr_module! {
    mod churon;
    impl RSession;
    impl TensorInfo;
}
#[cfg(
test)]
mod tests {
    use super::*;
    use ndarray::{ArrayD, IxDyn};
    use extendr_api::prelude::*;

    // Helper function to create test data
    fn create_test_doubles(data: Vec<f64>) -> Doubles {
        Doubles::from_values(data)
    }

    fn create_test_integers(data: Vec<i32>) -> Integers {
        Integers::from_values(data)
    }

    #[test]
    fn test_tensor_info_creation() {
        let tensor_info = TensorInfo::new(
            "test_tensor".to_string(),
            vec![2, 3, 4],
            "Float32".to_string()
        );
        
        assert_eq!(tensor_info.get_name(), "test_tensor");
        assert_eq!(tensor_info.get_shape(), vec![2, 3, 4]);
        assert_eq!(tensor_info.get_data_type(), "Float32");
    }

    #[test]
    fn test_tensor_info_getters() {
        let tensor_info = TensorInfo {
            name: "input_tensor".to_string(),
            shape: vec![1, 224, 224, 3],
            data_type: "Float32".to_string(),
        };
        
        assert_eq!(tensor_info.get_name(), "input_tensor");
        assert_eq!(tensor_info.get_shape(), vec![1, 224, 224, 3]);
        assert_eq!(tensor_info.get_data_type(), "Float32");
    }

    #[test]
    fn test_churon_error_display() {
        let model_error = ChurOnError::ModelLoad("Test model error".to_string());
        assert_eq!(format!("{}", model_error), "Model load error: Test model error");
        
        let inference_error = ChurOnError::Inference("Test inference error".to_string());
        assert_eq!(format!("{}", inference_error), "Inference error: Test inference error");
        
        let validation_error = ChurOnError::Validation("Test validation error".to_string());
        assert_eq!(format!("{}", validation_error), "Validation error: Test validation error");
        
        let conversion_error = ChurOnError::DataConversion("Test conversion error".to_string());
        assert_eq!(format!("{}", conversion_error), "Data conversion error: Test conversion error");
        
        let provider_error = ChurOnError::Provider("Test provider error".to_string());
        assert_eq!(format!("{}", provider_error), "Provider error: Test provider error");
    }

    #[test]
    fn test_data_converter_r_to_ndarray_f32() {
        let test_data = vec![1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
        let r_doubles = create_test_doubles(test_data.clone());
        let shape = vec![2, 3];
        
        let result = DataConverter::r_to_ndarray_f32(r_doubles, &shape);
        assert!(result.is_ok());
        
        let array = result.unwrap();
        assert_eq!(array.shape(), &[2, 3]);
        
        let expected_data: Vec<f32> = test_data.iter().map(|&x| x as f32).collect();
        let actual_data: Vec<f32> = array.iter().cloned().collect();
        assert_eq!(actual_data, expected_data);
    }

    #[test]
    fn test_data_converter_r_to_ndarray_f32_shape_mismatch() {
        let test_data = vec![1.0, 2.0, 3.0, 4.0];
        let r_doubles = create_test_doubles(test_data);
        let shape = vec![2, 3]; // Shape expects 6 elements, but we have 4
        
        let result = DataConverter::r_to_ndarray_f32(r_doubles, &shape);
        assert!(result.is_err());
        
        if let Err(ChurOnError::DataConversion(msg)) = result {
            assert!(msg.contains("Data length 4 doesn't match shape"));
        } else {
            panic!("Expected DataConversion error");
        }
    }

    #[test]
    fn test_data_converter_r_to_ndarray_f64() {
        let test_data = vec![1.5, 2.5, 3.5, 4.5];
        let r_doubles = create_test_doubles(test_data.clone());
        let shape = vec![2, 2];
        
        let result = DataConverter::r_to_ndarray_f64(r_doubles, &shape);
        assert!(result.is_ok());
        
        let array = result.unwrap();
        assert_eq!(array.shape(), &[2, 2]);
        
        let actual_data: Vec<f64> = array.iter().cloned().collect();
        assert_eq!(actual_data, test_data);
    }

    #[test]
    fn test_data_converter_r_to_ndarray_i32() {
        let test_data = vec![1, 2, 3, 4, 5, 6];
        let r_integers = create_test_integers(test_data.clone());
        let shape = vec![3, 2];
        
        let result = DataConverter::r_to_ndarray_i32(r_integers, &shape);
        assert!(result.is_ok());
        
        let array = result.unwrap();
        assert_eq!(array.shape(), &[3, 2]);
        
        let actual_data: Vec<i32> = array.iter().cloned().collect();
        assert_eq!(actual_data, test_data);
    }

    #[test]
    fn test_data_converter_r_to_ndarray_i64() {
        let test_data = vec![10, 20, 30, 40];
        let r_integers = create_test_integers(test_data.clone());
        let shape = vec![2, 2];
        
        let result = DataConverter::r_to_ndarray_i64(r_integers, &shape);
        assert!(result.is_ok());
        
        let array = result.unwrap();
        assert_eq!(array.shape(), &[2, 2]);
        
        let expected_data: Vec<i64> = test_data.iter().map(|&x| x as i64).collect();
        let actual_data: Vec<i64> = array.iter().cloned().collect();
        assert_eq!(actual_data, expected_data);
    }

    #[test]
    fn test_data_converter_ndarray_f32_to_r() {
        let test_data = vec![1.0f32, 2.0, 3.0, 4.0];
        let array = ArrayD::from_shape_vec(IxDyn(&[2, 2]), test_data.clone()).unwrap();
        
        let result = DataConverter::ndarray_f32_to_r(array);
        assert!(result.is_ok());
        
        let r_doubles = result.unwrap();
        let actual_data: Vec<f64> = r_doubles.iter().map(|x| x.0).collect();
        let expected_data: Vec<f64> = test_data.iter().map(|&x| x as f64).collect();
        assert_eq!(actual_data, expected_data);
    }

    #[test]
    fn test_data_converter_ndarray_f64_to_r() {
        let test_data = vec![1.5, 2.5, 3.5, 4.5];
        let array = ArrayD::from_shape_vec(IxDyn(&[2, 2]), test_data.clone()).unwrap();
        
        let result = DataConverter::ndarray_f64_to_r(array);
        assert!(result.is_ok());
        
        let r_doubles = result.unwrap();
        let actual_data: Vec<f64> = r_doubles.iter().map(|x| x.0).collect();
        assert_eq!(actual_data, test_data);
    }

    #[test]
    fn test_data_converter_ndarray_i32_to_r() {
        let test_data = vec![1, 2, 3, 4];
        let array = ArrayD::from_shape_vec(IxDyn(&[2, 2]), test_data.clone()).unwrap();
        
        let result = DataConverter::ndarray_i32_to_r(array);
        assert!(result.is_ok());
        
        let r_integers = result.unwrap();
        let actual_data: Vec<i32> = r_integers.iter().map(|x| x.0).collect();
        assert_eq!(actual_data, test_data);
    }

    #[test]
    fn test_data_converter_ndarray_i64_to_r() {
        let test_data = vec![10i64, 20, 30, 40];
        let array = ArrayD::from_shape_vec(IxDyn(&[2, 2]), test_data.clone()).unwrap();
        
        let result = DataConverter::ndarray_i64_to_r(array);
        assert!(result.is_ok());
        
        let r_integers = result.unwrap();
        let expected_data: Vec<i32> = test_data.iter().map(|&x| x as i32).collect();
        let actual_data: Vec<i32> = r_integers.iter().map(|x| x.0).collect();
        assert_eq!(actual_data, expected_data);
    }

    #[test]
    fn test_validate_input_data_success() {
        let data_shape = vec![2, 3, 4];
        let tensor_info = TensorInfo::new(
            "test".to_string(),
            vec![2, 3, 4],
            "Float32".to_string()
        );
        
        let result = DataConverter::validate_input_data(&data_shape, &tensor_info);
        assert!(result.is_ok());
    }

    #[test]
    fn test_validate_input_data_dynamic_dimension() {
        let data_shape = vec![5, 3, 4]; // First dimension is dynamic
        let tensor_info = TensorInfo::new(
            "test".to_string(),
            vec![-1, 3, 4], // -1 indicates dynamic dimension
            "Float32".to_string()
        );
        
        let result = DataConverter::validate_input_data(&data_shape, &tensor_info);
        assert!(result.is_ok());
    }

    #[test]
    fn test_validate_input_data_dimension_mismatch() {
        let data_shape = vec![2, 3]; // 2D
        let tensor_info = TensorInfo::new(
            "test".to_string(),
            vec![2, 3, 4], // 3D
            "Float32".to_string()
        );
        
        let result = DataConverter::validate_input_data(&data_shape, &tensor_info);
        assert!(result.is_err());
        
        if let Err(ChurOnError::Validation(msg)) = result {
            assert!(msg.contains("Shape dimension mismatch"));
        } else {
            panic!("Expected Validation error");
        }
    }

    #[test]
    fn test_validate_input_data_size_mismatch() {
        let data_shape = vec![2, 5, 4]; // Wrong size in second dimension
        let tensor_info = TensorInfo::new(
            "test".to_string(),
            vec![2, 3, 4], // Expected size 3 in second dimension
            "Float32".to_string()
        );
        
        let result = DataConverter::validate_input_data(&data_shape, &tensor_info);
        assert!(result.is_err());
        
        if let Err(ChurOnError::Validation(msg)) = result {
            assert!(msg.contains("Shape mismatch at dimension"));
        } else {
            panic!("Expected Validation error");
        }
    }

    #[test]
    fn test_execution_provider_parsing() {
        // Test valid providers
        let providers = vec!["cuda".to_string(), "cpu".to_string()];
        let result = RSession::get_execution_providers(Some(providers));
        assert!(result.is_ok());
        
        let execution_providers = result.unwrap();
        assert_eq!(execution_providers.len(), 2);
    }

    #[test]
    fn test_execution_provider_parsing_invalid() {
        // Test invalid provider
        let providers = vec!["invalid_provider".to_string()];
        let result = RSession::get_execution_providers(Some(providers));
        assert!(result.is_err());
        
        if let Err(ChurOnError::Provider(msg)) = result {
            assert!(msg.contains("Unknown execution provider"));
        } else {
            panic!("Expected Provider error");
        }
    }

    #[test]
    fn test_execution_provider_default() {
        // Test default providers (None input)
        let result = RSession::get_execution_providers(None);
        assert!(result.is_ok());
        
        let execution_providers = result.unwrap();
        assert!(!execution_providers.is_empty());
        
        // Should always include CPU as fallback
        assert!(execution_providers.iter().any(|ep| matches!(ep, ExecutionProvider::CPU(_))));
    }

    #[test]
    fn test_execution_provider_cpu_fallback() {
        // Test that CPU is added as fallback if not present
        let providers = vec!["cuda".to_string()];
        let result = RSession::get_execution_providers(Some(providers));
        assert!(result.is_ok());
        
        let execution_providers = result.unwrap();
        assert_eq!(execution_providers.len(), 2); // CUDA + CPU fallback
        assert!(execution_providers.iter().any(|ep| matches!(ep, ExecutionProvider::CPU(_))));
        assert!(execution_providers.iter().any(|ep| matches!(ep, ExecutionProvider::CUDA(_))));
    }
}