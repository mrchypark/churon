test_that("package loads successfully", {
  # Test that the package can be loaded without errors
  expect_true(require(churon, quietly = TRUE))

  # Test that the package namespace is available
  expect_true("churon" %in% loadedNamespaces())
})

test_that("exported functions are available", {
  # Check if main functions are exported and available
  exported_functions <- ls("package:churon")

  # Core functions that should be exported
  expected_functions <- c(
    # Core session functions
    "onnx_session",
    "onnx_run",
    "onnx_input_info",
    "onnx_output_info",
    "onnx_providers",
    "onnx_model_path",

    # Example model functions
    "onnx_example_models",
    "onnx_example_session",

    # Utility functions
    "find_model_path",
    "get_onnx_runtime_info",
    "check_onnx_runtime_available",
    "safe_onnx_session",
    "safe_onnx_run",
    "batch_process_data"
  )

  # Check that all expected functions are exported
  for (func in expected_functions) {
    expect_true(func %in% exported_functions,
                info = paste("Function", func, "should be exported"))
  }
})

test_that("package metadata is correct", {
  # Test package description
  desc <- packageDescription("churon")

  expect_equal(desc$Package, "churon")
  expect_match(desc$Title, "'ONNX' Runtime")
  expect_match(desc$Description, "ONNX")  # Check for ONNX mention
  expect_equal(desc$License, "MIT + file LICENSE")
})
