use extendr_api::*;
use extendr_api::prelude::*;
use tract_onnx::prelude::*;
/*use ndarray::{ArrayViewD, ArrayD};*/

pub struct RSession {
    runnable: Option<SimplePlan<TypedFact, Box<dyn TypedOp>, Graph<TypedFact, Box<dyn TypedOp>>>>,
}

#[extendr]
impl RSession {
    pub fn new() -> Self {
        RSession { runnable: None }
    }

    pub fn model_for_path(&mut self, path: &str) -> extendr_api::Result<()> {
        let result = tract_onnx::onnx()
            .model_for_path(path)
            .map_err(|e| extendr_api::Error::Other(e.to_string()))?;
        self.runnable = Some(result.into_optimized()
            .map_err(|e| extendr_api::Error::Other(e.to_string()))?
            .into_runnable()
            .map_err(|e| extendr_api::Error::Other(e.to_string()))?);
        Ok(())
    }

/*    pub fn run(&mut self, input: ArrayViewD<f32>) -> extendr_api::Result<Robj> {
        let runnable = match &self.runnable {
            Some(runnable) => runnable,
            None => return Err(extendr_api::Error::Other("Model not loaded".to_string())),
        };

        // Convert ArrayViewD to ArrayD
        let array = input.to_owned();

        // Convert ArrayD to Tensor
        let tensor = array.into_tensor();

        let result = runnable.run(tvec!(tensor.into()))
            .map_err(|e| extendr_api::Error::Other(e.to_string()))?;

        // 첫 번째 출력만을 가져온다 가정합니다.
        let tensor = result.get(0).ok_or_else(|| extendr_api::Error::Other("No output".to_string()))?;

        // Convert Tensor to ndarray
        let arr: ArrayD<f32> = tensor.to_array_view::<f32>().map_err(|e| extendr_api::Error::Other(e.to_string()))?;

        // Convert ndarray to Robj
        Ok(arr.try_into()?)
    }*/
}

extendr_module! {
    mod churon;
    impl RSession;
}
