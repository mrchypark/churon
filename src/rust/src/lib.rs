use extendr_api::prelude::*;
use ort::{
	environment::Environment,
	ExecutionProvider, GraphOptimizationLevel,
	LoggingLevel, SessionBuilder, Session, Value
};
use std::path::Path;

struct RSession {
    pub session: Session,
}

#[extendr]
impl RSession {
    pub fn from_path(path: &str) -> extendr_api::Result<Self> {
        let environment = Environment::builder()
            .with_name("churon")
            .with_log_level(LoggingLevel::Warning)
            .build()
            .map_err(|_| extendr_api::Error::EvalError("Failed to build environment".into()))?;

        let environment = environment.into_arc();

        let session = SessionBuilder::new(&environment)
            .map_err(|_| extendr_api::Error::EvalError("Failed to set environment to sessionbuilder".into()))?
            .with_optimization_level(GraphOptimizationLevel::Level1)
            .map_err(|_| extendr_api::Error::EvalError("Failed to set optimization level".into()))?
            .with_intra_threads(1)
            .map_err(|_| extendr_api::Error::EvalError("Failed to set intra threads".into()))?
            .with_execution_providers([
                ExecutionProvider::CUDA(Default::default()),
                ExecutionProvider::TensorRT(Default::default()),
                ExecutionProvider::DirectML(Default::default()),
                ExecutionProvider::OneDNN(Default::default()),
                ExecutionProvider::CoreML(Default::default()),
                ExecutionProvider::CPU(Default::default())
            ])
            .map_err(|_| extendr_api::Error::EvalError("Failed to set execution providers".into()))?
            .with_model_from_file(Path::new(path))
            .map_err(|_| extendr_api::Error::EvalError("Failed to load model".into()))?;

        Ok(RSession{session})
    }

    pub fn run(&self) {
        let data = vec![1; 200];

        let array = Array::from_shape_vec((200,), data).unwrap();
        let cow_array = ndarray::CowArray::from(array);

        let input_tensor_values = vec![Value::from_array(self.session.allocator(), &cow_array).map_err(|e| extendr_api::Error::from(Box::new(e)))?];

        // Perform the inference
        let _ = self.session.run();
    }

    pub fn check_input(&self) {
      let _ = println!("{:?}",&self.session.inputs);
    }
}

extendr_module! {
    mod churon;
    impl RSession;
}


