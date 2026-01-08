test_that("example models function works", {
  skip_if_not_installed("churon")
  library(churon)

  models <- onnx_example_models()

  # Should return available models
  expect_type(models, "character")
  expect_true(length(models) >= 1)
})

test_that("model path finding works", {
  skip_if_not_installed("churon")
  library(churon)

  # Test with non-existent file
  path <- find_model_path("/path/to/nonexistent.onnx")
  expect_false(file.exists(path))
  expect_match(path, "nonexistent\\.onnx$")

  # Test with existing file
  temp_file <- tempfile(fileext = ".onnx")
  writeLines("dummy", temp_file)
  on.exit(unlink(temp_file))

  path <- find_model_path(temp_file)
  expect_true(file.exists(path))
  expect_match(path, "\\.onnx$")
})
