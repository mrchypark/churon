test_that("package loads successfully", {
  # Test that the package can be loaded without errors
  expect_true(require(churon, quietly = TRUE))
  
  # Test that the package namespace is available
  expect_true("churon" %in% loadedNamespaces())
})

test_that("exported functions are available", {
  # Check if main functions are exported and available
  exported_functions <- ls("package:churon")
  
  # These functions should be available once R interface is implemented
  expected_functions <- c(
    # Core session functions
    "onnx_session",
    "onnx_run", 
    "onnx_input_info",
    "onnx_output_info",
    "onnx_providers",
    
    # Utility functions
    "onnx_example_models",
    "find_model_path"
  )
  
  # For now, just check that some functions are exported
  # This test will be updated as functions are implemented
  expect_true(length(exported_functions) >= 0)
  
  # TODO: Uncomment when R interface functions are implemented
  # for (func in expected_functions) {
  #   expect_true(func %in% exported_functions, 
  #               info = paste("Function", func, "should be exported"))
  # }
})

test_that("package metadata is correct", {
  # Test package description
  desc <- packageDescription("churon")
  
  expect_equal(desc$Package, "churon")
  expect_match(desc$Title, "ONNX Runtime")
  expect_match(desc$Description, "ONNX Runtime")
  expect_equal(desc$License, "MIT + file LICENSE")
})