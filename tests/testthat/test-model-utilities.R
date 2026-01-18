test_that("example model paths are accessible", {
  # Test that model directory exists in the package
  model_dir <- system.file("model", package = "churon")
  expect_true(dir.exists(model_dir))

  # Check for expected model files
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)
  expect_true(length(model_files) > 0, info = "At least one model should be bundled")
  expect_true("mnist.onnx" %in% basename(model_files), info = "MNIST model should be bundled")
})

test_that("model file validation works", {
  # Test with valid model path
  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)

  if (length(model_files) > 0) {
    # Test that model files exist and are readable
    for (model_file in model_files) {
      expect_true(file.exists(model_file))
      expect_true(file.access(model_file, mode = 4) == 0, info = paste(model_file, "should be readable"))
      expect_true(file.size(model_file) > 0, info = paste(model_file, "should not be empty"))
    }
  }
})

test_that("invalid model paths are handled correctly", {
  skip_on_os("windows")
  # Test with non-existent file
  expect_error(
    onnx_session("/path/to/nonexistent/model.onnx"),
    "Model file not found"
  )

  # Test with invalid file format
  temp_file <- tempfile(fileext = ".txt")
  writeLines("not an onnx model", temp_file)
  on.exit(unlink(temp_file))

  expect_error(
    suppressWarnings(onnx_session(temp_file)),
    "Failed to create ONNX session"
  )
})
