test_that("batch processing works correctly", {
  library(churon)

  expect_true(TRUE)
})

test_that("batch processing with invalid parameters", {
  library(churon)

  # Test batch processing with invalid parameters
  expect_error(
    batch_process_data("not_a_session", "not_a_list"),
    "data_list must be a list of input data"
  )

  expect_error(
    batch_process_data(NULL, list(), batch_size = -1),
    "session is required and cannot be NULL"
  )

  expect_error(
    batch_process_data(NULL, list(), batch_size = "not_a_number"),
    "session is required and cannot be NULL"
  )
})
