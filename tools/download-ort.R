# pub(crate) static ref G_ORT_DYLIB_PATH: Arc<String> = {
#   let path = match std::env::var("ORT_DYLIB_PATH") {
#     Ok(s) if !s.is_empty() => s,
#     #[cfg(target_os = "windows")]
#     _ => "onnxruntime.dll".to_owned(),
#     #[cfg(any(target_os = "linux", target_os = "android"))]
#     _ => "libonnxruntime.so".to_owned(),
#     #[cfg(target_os = "macos")]
#     _ => "libonnxruntime.dylib".to_owned()
#   };
#   Arc::new(path)

# if (!file.exists("../windows/rwinlib-elbird-0.11.2/include/kiwi/capi.h")) {
#
#   if (getRversion() < "3.3.0") setInternet2()
#   download.file("https://github.com/mrchypark/rwinlib-elbird/archive/refs/tags/v0.11.2.zip", destfile = "kiwi-release.zip", quiet = TRUE)
#   dir.create("../windows", showWarnings = FALSE)
#   unzip("kiwi-release.zip", exdir = "../windows")
#   unlink("kiwi-release.zip")
#
# }
#
#
# download.file("https://github.com/microsoft/onnxruntime/releases/download/v1.15.0/onnxruntime-linux-x64-1.15.0.tgz", "ort.tgz")
# untar("ort.tgz")
# Sys.setenv("ORT_DYLIB_PATH"= "onnxruntime-linux-x64-1.15.0/lib/libonnxruntime.so")
