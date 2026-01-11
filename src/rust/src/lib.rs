use extendr_api::prelude::*;
use crate::ndarray::{ArrayD, IxDyn};
use ort::execution_providers::ExecutionProviderDispatch;
use ort::session::{builder::GraphOptimizationLevel, Session};
use ort::value::{Tensor, Value};
use std::collections::HashMap;
use std::fmt;
use std::path::Path;
use std::sync::Once;

static ORT_INIT: Once = Once::new();

#[derive(Debug, Clone)]
#[extendr]
pub struct TensorInfo {
    pub name: String,
    pub shape: Vec<i32>,
    pub data_type: String,
}

#[extendr]
impl TensorInfo {
    pub fn new(name: String, shape: Vec<i32>, data_type: String) -> Self {
        TensorInfo {
            name,
            shape,
            data_type,
        }
    }

    pub fn get_name(&self) -> String {
        self.name.clone()
    }

    pub fn get_shape(&self) -> Vec<i32> {
        self.shape.clone()
    }

    pub fn get_data_type(&self) -> String {
        self.data_type.clone()
    }
}

#[derive(Debug, Clone)]
pub enum ChurOnError {
    ModelLoad(String),
    Inference(String),
    DataConversion(String),
    Validation(String),
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

impl From<ChurOnError> for extendr_api::Error {
    fn from(err: ChurOnError) -> Self {
        match err {
            ChurOnError::ModelLoad(msg) => {
                extendr_api::Error::EvalError(format!("Model load failed: {}", msg).into())
            }
            ChurOnError::Inference(msg) => {
                extendr_api::Error::EvalError(format!("Inference failed: {}", msg).into())
            }
            ChurOnError::DataConversion(msg) => {
                extendr_api::Error::EvalError(format!("Data conversion failed: {}", msg).into())
            }
            ChurOnError::Validation(msg) => {
                extendr_api::Error::EvalError(format!("Input validation failed: {}", msg).into())
            }
            ChurOnError::Provider(msg) => {
                extendr_api::Error::EvalError(format!("Execution provider error: {}", msg).into())
            }
        }
    }
}

pub type ChurOnResult<T> = std::result::Result<T, ChurOnError>;

#[extendr]
pub struct RSession {
    pub session: Session,
    pub input_names: Vec<String>,
    pub output_names: Vec<String>,
    pub input_shapes: Vec<Vec<i64>>,
    pub output_shapes: Vec<Vec<i64>>,
    pub providers: Vec<String>,
    pub model_path: String,
    input_info_cache: Option<Vec<TensorInfo>>,
    output_info_cache: Option<Vec<TensorInfo>>,
}

#[extendr]
impl RSession {
    pub fn from_path(path: &str) -> extendr_api::Result<Self> {
        Self::from_path_with_providers_internal(path, None)
    }

    pub fn check_input(&self) {
        extendr_api::rprintln!("Input names: {:?}", &self.input_names);
        extendr_api::rprintln!("Input shapes: {:?}", &self.input_shapes);
    }

    pub fn get_input_info(&mut self) -> List {
        if let Some(ref cached_info) = self.input_info_cache {
            return List::from_values(cached_info.clone());
        }

        let inputs = self.session.inputs();
        let tensor_infos: Vec<TensorInfo> = inputs
            .iter()
            .enumerate()
            .map(|(i, input)| {
                let shape_i64 = self.input_shapes.get(i).cloned().unwrap_or_default();
                let shape_i32: Vec<i32> = shape_i64.iter().map(|&x| x as i32).collect();
                TensorInfo::new(
                    input.name().to_string(),
                    shape_i32,
                    format!("{:?}", input.dtype()),
                )
            })
            .collect();

        self.input_info_cache = Some(tensor_infos.clone());
        List::from_values(tensor_infos)
    }

    pub fn get_output_info(&mut self) -> List {
        if let Some(ref cached_info) = self.output_info_cache {
            return List::from_values(cached_info.clone());
        }

        let outputs = self.session.outputs();
        let tensor_infos: Vec<TensorInfo> = outputs
            .iter()
            .enumerate()
            .map(|(i, output)| {
                let shape_i64 = self.output_shapes.get(i).cloned().unwrap_or_default();
                let shape_i32: Vec<i32> = shape_i64.iter().map(|&x| x as i32).collect();
                TensorInfo::new(
                    output.name().to_string(),
                    shape_i32,
                    format!("{:?}", output.dtype()),
                )
            })
            .collect();

        self.output_info_cache = Some(tensor_infos.clone());
        List::from_values(tensor_infos)
    }

    pub fn get_providers(&self) -> Vec<String> {
        self.providers.clone()
    }

    pub fn get_model_path(&self) -> String {
        self.model_path.clone()
    }

    fn run(&mut self, inputs: List) -> extendr_api::Result<List> {
        self.validate_session()?;
        self.validate_inputs(&inputs)?;
        let input_data = self.prepare_input_tensors(inputs)?;
        let ort_inputs = self.convert_to_ort_values(input_data)?;

        // Clone output names before the mutable borrow scope
        let output_names = self.output_names.clone();

        // Use a block to limit the mutable borrow scope
        let outputs = {
            self.session
                .run(ort_inputs)
                .map_err(|e| ChurOnError::Inference(format!("Inference execution failed: {}", e)))?
        };

        Self::extract_outputs(outputs, &output_names)
    }
}

impl RSession {
    fn validate_session(&self) -> ChurOnResult<()> {
        if self.input_names.is_empty() {
            return Err(ChurOnError::Validation(
                "Session has no input tensors defined".to_string(),
            ));
        }
        if self.output_names.is_empty() {
            return Err(ChurOnError::Validation(
                "Session has no output tensors defined".to_string(),
            ));
        }
        if self.model_path.is_empty() {
            return Err(ChurOnError::Validation(
                "Session has no model path defined".to_string(),
            ));
        }
        Ok(())
    }

    fn validate_inputs(&self, inputs: &List) -> ChurOnResult<()> {
        if inputs.len() == 0 {
            return Err(ChurOnError::Validation(
                "No input data provided".to_string(),
            ));
        }
        let input_names = inputs.names().unwrap_or_default();
        if input_names.len() == 0 {
            return Err(ChurOnError::Validation(
                "Input data must be a named list".to_string(),
            ));
        }
        let provided_input_names: Vec<String> = input_names.map(|name| name.to_string()).collect();
        for required_input in &self.input_names {
            if !provided_input_names.contains(required_input) {
                return Err(ChurOnError::Validation(format!(
                    "Required input '{}' not provided",
                    required_input
                )));
            }
        }
        for provided_name in &provided_input_names {
            if !self.input_names.contains(provided_name) {
                return Err(ChurOnError::Validation(format!(
                    "Unexpected input '{}' provided",
                    provided_name
                )));
            }
        }
        Ok(())
    }

    fn prepare_input_tensors(
        &self,
        inputs: List,
    ) -> ChurOnResult<(HashMap<String, ArrayD<f32>>, HashMap<String, Vec<String>>)> {
        let mut numeric_tensors = HashMap::new();
        let mut string_tensors = HashMap::new();
        let input_names = inputs.names().unwrap_or_default();

        for (i, input_name) in input_names.enumerate() {
            let input_name_str = input_name;
            let input_robj = inputs.index(i + 1).map_err(|e| {
                ChurOnError::DataConversion(format!(
                    "Failed to access input at index {}: {}",
                    i + 1,
                    e
                ))
            })?;

            // Check if input is numeric or string
            if input_robj.is_string() || input_robj.is_char() {
                // Extract string data
                if let Some(strs) = input_robj.as_str_vector() {
                    string_tensors.insert(
                        input_name_str.to_string(),
                        strs.iter().map(|s| s.to_string()).collect(),
                    );
                } else if let Some(single_str) = input_robj.as_str() {
                    string_tensors.insert(input_name_str.to_string(), vec![single_str.to_string()]);
                } else {
                    return Err(ChurOnError::DataConversion(format!(
                        "Failed to convert input '{}' to string data",
                        input_name_str
                    )));
                }
            } else {
                // Numeric input
                let expected_shape =
                    if let Some(idx) = self.input_names.iter().position(|x| x == input_name_str) {
                        self.input_shapes.get(idx).cloned().unwrap_or_default()
                    } else {
                        return Err(ChurOnError::Validation(format!(
                            "Unknown input name: {}",
                            input_name_str
                        )));
                    };
                let shape_usize: Vec<usize> = expected_shape
                    .iter()
                    .map(|&x| if x == -1 { 1 } else { x as usize })
                    .collect();

                // Extract numeric data from R object (handles matrices, arrays, vectors)
                let tensor = DataConverter::r_obj_to_ndarray_f32(&input_robj, &shape_usize)?;
                numeric_tensors.insert(input_name_str.to_string(), tensor);
            }
        }
        Ok((numeric_tensors, string_tensors))
    }

    fn convert_to_ort_values(
        &self,
        input_data: (HashMap<String, ArrayD<f32>>, HashMap<String, Vec<String>>),
    ) -> ChurOnResult<HashMap<String, Value>> {
        let (numeric_tensors, string_tensors) = input_data;
        let mut values: HashMap<String, Value> = HashMap::new();

        // Handle numeric tensors
        for input_name in &self.input_names {
            if let Some(tensor) = numeric_tensors.get(input_name) {
                let shape: Vec<usize> = tensor.shape().iter().map(|&d| d as usize).collect();
                let data: Vec<f32> = tensor.iter().cloned().collect();
                let ort_tensor = Tensor::from_array((shape, data)).map_err(|e| {
                    ChurOnError::DataConversion(format!(
                        "Failed to create tensor for input '{}': {}",
                        input_name, e
                    ))
                })?;
                let value: Value = ort_tensor.into();
                values.insert(input_name.clone(), value);
            }
        }

        // Handle string tensors using Tensor::from_string_array
        for (input_name, string_data) in &string_tensors {
            let shape = [string_data.len()];
            // Create owned string array to avoid lifetime issues
            let string_array: Vec<String> = string_data.iter().map(|s| s.to_string()).collect();
            let ort_tensor =
                Tensor::from_string_array((shape, string_array.as_slice())).map_err(|e| {
                    ChurOnError::DataConversion(format!(
                        "Failed to create string tensor for input '{}': {}",
                        input_name, e
                    ))
                })?;
            let value: Value = ort_tensor.into();
            values.insert(input_name.clone(), value);
        }

        Ok(values)
    }

    fn extract_outputs(
        outputs: ort::session::SessionOutputs,
        output_names: &[String],
    ) -> extendr_api::Result<List> {
        let mut r_outputs = Vec::new();
        let mut out_names = Vec::new();
        for output_name in output_names {
            let name = output_name.clone();
            let output = outputs
                .get(&name)
                .ok_or_else(|| ChurOnError::Inference(format!("Output '{}' not found", name)))?;

            // Try numeric f32 output
            let r_data = match output.try_extract_array::<f32>() {
                Ok(array_view) => {
                    let shape: Vec<usize> = array_view.shape().to_vec();
                    let data: Vec<f32> = array_view.iter().cloned().collect();
                    let array = ArrayD::from_shape_vec(IxDyn(&shape), data).map_err(|e| {
                        ChurOnError::DataConversion(format!("Failed to create output array: {}", e))
                    })?;
                    let converted = DataConverter::ndarray_f32_to_r(array)?;
                    converted.into_robj()
                }
                Err(_) => match output.try_extract_array::<f64>() {
                    Ok(array_view) => {
                        let shape: Vec<usize> = array_view.shape().to_vec();
                        let data: Vec<f64> = array_view.iter().cloned().collect();
                        let array = ArrayD::from_shape_vec(IxDyn(&shape), data).map_err(|e| {
                            ChurOnError::DataConversion(format!(
                                "Failed to create output array: {}",
                                e
                            ))
                        })?;
                        let converted = DataConverter::ndarray_f64_to_r(array)?;
                        converted.into_robj()
                    }
                    Err(_) => {
                        return Err(ChurOnError::DataConversion(format!(
                            "Unsupported output data type for '{}'",
                            name
                        ))
                        .into());
                    }
                },
            };
            r_outputs.push(r_data);
            out_names.push(name);
        }
        let mut result = List::from_values(r_outputs);
        result.set_names(out_names)?;
        Ok(result)
    }
}

impl RSession {
    fn from_path_with_providers_internal(
        path: &str,
        providers: Option<Vec<String>>,
    ) -> extendr_api::Result<Self> {
        // Use Once to ensure ort initialization happens only once
        // This prevents mutex poisoning when called concurrently
        ORT_INIT.call_once(|| {
            // Try to get ORT_DYLIB_PATH from environment
            let dylib_path = std::env::var("ORT_DYLIB_PATH")
                .ok()
                .filter(|p| !p.is_empty());

            // Initialize ONNX Runtime with panic recovery
            // ort::init_from() may panic if library is invalid, so we catch it
            let init_result = std::panic::catch_unwind(|| {
                if let Some(path) = dylib_path {
                    ort::init_from(path)
                } else {
                    Ok(ort::init())
                }
            });

            // Log any initialization errors but don't panic
            // Let R handle the "not installed" case gracefully
            match init_result {
                Ok(Ok(env)) => {
                    let _ = env.commit();
                }
                Ok(Err(e)) => {
                    extendr_api::rprintln!("Warning: ONNX Runtime initialization failed: {}", e);
                }
                Err(_) => {
                    extendr_api::rprintln!("Warning: ONNX Runtime initialization panicked (possible corrupted library)");
                }
            }
        });
        let execution_providers = Self::get_execution_providers(providers)?;
        let session = Session::builder()
            .map_err(|e| {
                ChurOnError::ModelLoad(format!("Failed to create session builder: {}", e))
            })?
            .with_optimization_level(GraphOptimizationLevel::Level1)
            .map_err(|e| {
                ChurOnError::ModelLoad(format!("Failed to set optimization level: {}", e))
            })?
            .with_intra_threads(1)
            .map_err(|e| ChurOnError::ModelLoad(format!("Failed to set intra threads: {}", e)))?
            .with_execution_providers(execution_providers)
            .map_err(|e| {
                ChurOnError::Provider(format!("Failed to set execution providers: {}", e))
            })?
            .commit_from_file(Path::new(path))
            .map_err(|e| {
                ChurOnError::ModelLoad(format!("Failed to load model from {}: {}", path, e))
            })?;
        let inputs = session.inputs();
        let outputs = session.outputs();
        let input_names: Vec<String> = inputs
            .iter()
            .map(|input| input.name().to_string())
            .collect();
        let output_names: Vec<String> = outputs
            .iter()
            .map(|output| output.name().to_string())
            .collect();

        // In ort v2, Outlet doesn't expose dimensions directly.
        // Use placeholder shapes - user must provide correct shapes at inference time.
        let input_shapes: Vec<Vec<i64>> = inputs
            .iter()
            .map(|_| vec![-1]) // Placeholder - dynamic dimension
            .collect();
        let output_shapes: Vec<Vec<i64>> = outputs
            .iter()
            .map(|_| vec![-1]) // Placeholder - dynamic dimension
            .collect();
        Ok(RSession {
            session,
            input_names,
            output_names,
            input_shapes,
            output_shapes,
            providers: vec!["CPU".to_string()],
            model_path: path.to_string(),
            input_info_cache: None,
            output_info_cache: None,
        })
    }

    fn get_execution_providers(
        providers: Option<Vec<String>>,
    ) -> ChurOnResult<Vec<ExecutionProviderDispatch>> {
        match providers {
            Some(provider_names) => {
                let mut execution_providers = Vec::new();
                let mut has_cpu = false;
                for provider_name in provider_names {
                    match provider_name.to_lowercase().as_str() {
                        "cuda" => execution_providers.push(
                            ort::execution_providers::CUDAExecutionProvider::default().build(),
                        ),
                        "tensorrt" => execution_providers.push(
                            ort::execution_providers::TensorRTExecutionProvider::default().build(),
                        ),
                        "directml" => execution_providers.push(
                            ort::execution_providers::DirectMLExecutionProvider::default().build(),
                        ),
                        "onednn" => execution_providers.push(
                            ort::execution_providers::OneDNNExecutionProvider::default().build(),
                        ),
                        "coreml" => execution_providers.push(
                            ort::execution_providers::CoreMLExecutionProvider::default().build(),
                        ),
                        "cpu" => {
                            execution_providers.push(
                                ort::execution_providers::CPUExecutionProvider::default().build(),
                            );
                            has_cpu = true;
                        }
                        _ => {
                            return Err(ChurOnError::Provider(format!(
                                "Unknown execution provider: {}",
                                provider_name
                            )))
                        }
                    }
                }
                if !has_cpu {
                    execution_providers
                        .push(ort::execution_providers::CPUExecutionProvider::default().build());
                }
                Ok(execution_providers)
            }
            None => {
                let mut execution_providers = Vec::new();
                #[cfg(target_os = "macos")]
                {
                    execution_providers
                        .push(ort::execution_providers::CoreMLExecutionProvider::default().build());
                }
                #[cfg(target_os = "windows")]
                {
                    execution_providers.push(
                        ort::execution_providers::DirectMLExecutionProvider::default().build(),
                    );
                }
                execution_providers.extend_from_slice(&[
                    ort::execution_providers::CUDAExecutionProvider::default().build(),
                    ort::execution_providers::OneDNNExecutionProvider::default().build(),
                    ort::execution_providers::CPUExecutionProvider::default().build(),
                ]);
                Ok(execution_providers)
            }
        }
    }
}

pub struct DataConverter;

impl DataConverter {
    pub fn r_to_ndarray_f32(r_data: Doubles, shape: &[usize]) -> ChurOnResult<ArrayD<f32>> {
        let data: Vec<f32> = r_data.iter().map(|x| x.inner() as f32).collect();
        let total_elements: usize = shape.iter().product();
        if data.len() != total_elements {
            return Err(ChurOnError::DataConversion(format!(
                "Data length {} doesn't match shape {:?}",
                data.len(),
                shape
            )));
        }
        ArrayD::from_shape_vec(IxDyn(shape), data)
            .map_err(|e| ChurOnError::DataConversion(format!("Failed to create ndarray: {}", e)))
    }

    /// Convert R object (vector, matrix, array) to ndarray f32
    pub fn r_obj_to_ndarray_f32(
        robj: &Robj,
        expected_shape: &[usize],
    ) -> ChurOnResult<ArrayD<f32>> {
        // Get dimensions from R object
        let actual_shape: Vec<usize> = if let Some(dims) = robj.dim() {
            dims.iter().map(|d| d.inner() as usize).collect()
        } else {
            vec![robj.len()]
        };

        // Determine effective shape
        let effective_shape: Vec<usize> = if expected_shape.iter().any(|&x| x == 0 || x == 1) {
            // If expected shape has zeros or ones, use actual shape
            actual_shape.clone()
        } else {
            expected_shape.to_vec()
        };

        // Extract numeric data as f64 first, then convert to f32
        let data_f32: Vec<f32> = if let Some(doubles) = robj.as_real_slice() {
            doubles.iter().map(|&x| x as f32).collect()
        } else if let Some(ints) = robj.as_integer_slice() {
            ints.iter().map(|&x| x as f32).collect()
        } else {
            return Err(ChurOnError::DataConversion(
                "Input must be numeric (integer or real)".to_string(),
            ));
        };

        let total_elements: usize = effective_shape.iter().product();
        if data_f32.len() != total_elements {
            return Err(ChurOnError::DataConversion(format!(
                "Data length {} doesn't match expected shape {:?} (expected {} elements)",
                data_f32.len(),
                effective_shape,
                total_elements
            )));
        }

        ArrayD::from_shape_vec(IxDyn(&effective_shape), data_f32)
            .map_err(|e| ChurOnError::DataConversion(format!("Failed to create ndarray: {}", e)))
    }

    pub fn r_to_ndarray_f64(r_data: Doubles, shape: &[usize]) -> ChurOnResult<ArrayD<f64>> {
        let data: Vec<f64> = r_data.iter().map(|x| x.inner() as f64).collect();
        let total_elements: usize = shape.iter().product();
        if data.len() != total_elements {
            return Err(ChurOnError::DataConversion(format!(
                "Data length {} doesn't match shape {:?}",
                data.len(),
                shape
            )));
        }
        ArrayD::from_shape_vec(IxDyn(shape), data)
            .map_err(|e| ChurOnError::DataConversion(format!("Failed to create ndarray: {}", e)))
    }

    pub fn ndarray_f32_to_r(array: ArrayD<f32>) -> ChurOnResult<Doubles> {
        let data: Vec<f64> = array.iter().map(|&x| x as f64).collect();
        Ok(Doubles::from_values(data))
    }

    pub fn ndarray_f64_to_r(array: ArrayD<f64>) -> ChurOnResult<Doubles> {
        let data: Vec<f64> = array.iter().cloned().collect();
        Ok(Doubles::from_values(data))
    }
}

extendr_module! {
    mod churon;
    impl RSession;
    impl TensorInfo;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tensor_info_creation() {
        let tensor_info = TensorInfo::new(
            "test_tensor".to_string(),
            vec![2, 3, 4],
            "Float32".to_string(),
        );
        assert_eq!(tensor_info.get_name(), "test_tensor");
        assert_eq!(tensor_info.get_shape(), vec![2, 3, 4]);
        assert_eq!(tensor_info.get_data_type(), "Float32");
    }

    #[test]
    fn test_data_converter_r_to_ndarray_f32() {
        let test_data = vec![1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
        let r_doubles = Doubles::from_values(test_data.clone());
        let shape = vec![2, 3];
        let result = DataConverter::r_to_ndarray_f32(r_doubles, &shape);
        assert!(result.is_ok());
        let array = result.unwrap();
        assert_eq!(array.shape(), &[2, 3]);
    }
}
