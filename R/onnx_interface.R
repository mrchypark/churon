#' @importFrom utils download.file
NULL

#' Create ONNX Session
#'
#' Create a new ONNX Runtime session from a model file.
#'
#' @param model_path Character string specifying the path to the ONNX model file
#' @param providers Optional character vector specifying execution providers to use.
#'   Available providers: "cuda", "tensorrt", "directml", "onednn", "coreml", "cpu".
#'   If NULL, uses default provider priority.
#' @return An RSession object for running inference
#' @export
#' @examples
#' \dontrun{
#' # Create session with default providers
#' session <- onnx_session("path/to/model.onnx")
#' 
#' # Create session with specific providers
#' session <- onnx_session("path/to/model.onnx", providers = c("cuda", "cpu"))
#' }
onnx_session <- function(model_path, providers = NULL) {
  # Input validation
  if (missing(model_path) || is.null(model_path)) {
    stop("model_path is required and cannot be NULL")
  }
  
  if (!is.character(model_path) || length(model_path) != 1) {
    stop("model_path must be a single character string")
  }
  
  if (nchar(model_path) == 0) {
    stop("model_path cannot be empty")
  }
  
  if (!file.exists(model_path)) {
    stop("Model file not found: ", model_path, 
         "\nPlease check the file path and ensure the file exists.")
  }
  
  # Check file extension
  if (!grepl("\\.onnx$", model_path, ignore.case = TRUE)) {
    warning("Model file does not have .onnx extension. This may not be a valid ONNX model.")
  }
  
  # Validate providers if provided
  if (!is.null(providers)) {
    if (!is.character(providers)) {
      stop("providers must be a character vector")
    }
    
    valid_providers <- c("cuda", "tensorrt", "directml", "onednn", "coreml", "cpu")
    invalid_providers <- providers[!tolower(providers) %in% valid_providers]
    
    if (length(invalid_providers) > 0) {
      stop("Invalid execution providers: ", paste(invalid_providers, collapse = ", "), 
           "\nValid providers are: ", paste(valid_providers, collapse = ", "))
    }
  }
  
  tryCatch({
    session <- RSession$from_path(model_path)
    
    # Validate session was created successfully
    if (is.null(session)) {
      stop("Session creation returned NULL")
    }
    
    return(session)
  }, error = function(e) {
    # Provide more helpful error messages based on error type
    error_msg <- e$message
    
    if (grepl("libonnxruntime", error_msg)) {
      stop("ONNX Runtime library not found. Please install ONNX Runtime or check your installation.\n",
           "Original error: ", error_msg)
    } else if (grepl("Model load failed", error_msg)) {
      stop("Failed to load ONNX model. The file may be corrupted or not a valid ONNX model.\n",
           "Model path: ", model_path, "\n",
           "Original error: ", error_msg)
    } else {
      stop("Failed to create ONNX session: ", error_msg)
    }
  })
}

#' Run ONNX Inference
#'
#' Execute inference on an ONNX model with input data.
#'
#' @param session An RSession object created by onnx_session()
#' @param inputs A named list of input tensors. Names should match model input names.
#' @return A named list of output tensors
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' inputs <- list(input_tensor = matrix(rnorm(10), nrow = 2, ncol = 5))
#' outputs <- onnx_run(session, inputs)
#' }
onnx_run <- function(session, inputs) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  # Validate inputs parameter
  if (missing(inputs) || is.null(inputs)) {
    stop("inputs is required and cannot be NULL")
  }
  
  if (!is.list(inputs)) {
    stop("inputs must be a named list of tensors")
  }
  
  if (length(inputs) == 0) {
    stop("inputs cannot be empty. At least one input tensor is required.")
  }
  
  # Check if inputs are named
  input_names <- names(inputs)
  if (is.null(input_names) || any(input_names == "") || any(is.na(input_names))) {
    stop("All inputs must be named. Please provide a named list where names match model input names.")
  }
  
  # Check for duplicate names
  if (any(duplicated(input_names))) {
    duplicates <- input_names[duplicated(input_names)]
    stop("Duplicate input names found: ", paste(duplicates, collapse = ", "))
  }
  
  # Validate input data types
  for (i in seq_along(inputs)) {
    input_name <- input_names[i]
    input_data <- inputs[[i]]
    
    if (is.null(input_data)) {
      stop("Input '", input_name, "' cannot be NULL")
    }
    
    # Allow both numeric and character (string) inputs
    if (!is.numeric(input_data) && !is.character(input_data)) {
      stop("Input '", input_name, "' must be numeric (matrix, vector, or array) or character (string)")
    }
    
    if (is.numeric(input_data) && any(is.na(input_data))) {
      warning("Input '", input_name, "' contains NA values. This may cause inference to fail.")
    }
    
    if (is.numeric(input_data) && any(is.infinite(input_data))) {
      warning("Input '", input_name, "' contains infinite values. This may cause inference to fail.")
    }
  }
  
  tryCatch({
    result <- session$run(inputs)
    
    # Validate result
    if (is.null(result)) {
      stop("Inference returned NULL result")
    }
    
    return(result)
  }, error = function(e) {
    error_msg <- e$message
    
    # Provide more specific error messages based on error type
    if (grepl("Required input.*not provided", error_msg)) {
      stop("Missing required input tensor. ", error_msg, 
           "\nPlease check the model's input requirements using onnx_input_info(session)")
    } else if (grepl("Unexpected input.*provided", error_msg)) {
      stop("Unexpected input tensor provided. ", error_msg,
           "\nPlease check the model's input requirements using onnx_input_info(session)")
    } else if (grepl("Shape mismatch", error_msg)) {
      stop("Input tensor shape mismatch. ", error_msg,
           "\nPlease check the expected input shapes using onnx_input_info(session)")
    } else if (grepl("Data conversion failed", error_msg)) {
      stop("Failed to convert input data. ", error_msg,
           "\nPlease ensure all inputs are numeric and have the correct dimensions.")
    } else if (grepl("Tensor conversion not yet implemented", error_msg)) {
      stop("ONNX tensor conversion is not yet fully implemented. ",
           "This is a known limitation of the current version.")
    } else {
      stop("Inference failed: ", error_msg)
    }
  })
}

#' Get Input Information
#'
#' Retrieve information about model input tensors.
#'
#' @param session An RSession object created by onnx_session()
#' @return A list of TensorInfo objects containing input tensor metadata
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' input_info <- onnx_input_info(session)
#' print(input_info)
#' }
onnx_input_info <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    result <- session$get_input_info()
    
    if (is.null(result)) {
      warning("No input information available for this model")
      return(list())
    }
    
    return(result)
  }, error = function(e) {
    stop("Failed to retrieve input information: ", e$message)
  })
}

#' Get Output Information
#'
#' Retrieve information about model output tensors.
#'
#' @param session An RSession object created by onnx_session()
#' @return A list of TensorInfo objects containing output tensor metadata
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' output_info <- onnx_output_info(session)
#' print(output_info)
#' }
onnx_output_info <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    result <- session$get_output_info()
    
    if (is.null(result)) {
      warning("No output information available for this model")
      return(list())
    }
    
    return(result)
  }, error = function(e) {
    stop("Failed to retrieve output information: ", e$message)
  })
}

#' Get Execution Providers
#'
#' Retrieve information about execution providers used by the session.
#'
#' @param session An RSession object created by onnx_session()
#' @return A character vector of execution provider names
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' providers <- onnx_providers(session)
#' print(providers)
#' }
onnx_providers <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    result <- session$get_providers()
    
    if (is.null(result) || length(result) == 0) {
      warning("No execution provider information available")
      return(character(0))
    }
    
    return(result)
  }, error = function(e) {
    stop("Failed to retrieve execution provider information: ", e$message)
  })
}

#' Get Model Path
#'
#' Retrieve the file path of the loaded model.
#'
#' @param session An RSession object created by onnx_session()
#' @return A character string containing the model file path
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' model_path <- onnx_model_path(session)
#' print(model_path)
#' }
onnx_model_path <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    result <- session$get_model_path()
    
    if (is.null(result) || nchar(result) == 0) {
      warning("No model path information available")
      return("")
    }
    
    return(result)
  }, error = function(e) {
    stop("Failed to retrieve model path: ", e$message)
  })
}

#' Get Example Model Paths
#'
#' Retrieve paths to example ONNX models included in the package.
#'
#' @return A named character vector of model paths
#' @export
#' @examples
#' \dontrun{
#' models <- onnx_example_models()
#' print(models)
#' 
#' # Use an example model
#' session <- onnx_session(models["kospacing"])
#' }
onnx_example_models <- function() {
  model_dir <- system.file("model", package = "churon")
  
  if (!dir.exists(model_dir)) {
    warning("No example models found in package installation")
    return(character(0))
  }
  
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)
  
  if (length(model_files) == 0) {
    warning("No ONNX model files found in package")
    return(character(0))
  }
  
  # Create named vector with model names (without extension) as names
  model_names <- tools::file_path_sans_ext(basename(model_files))
  names(model_files) <- model_names
  
  return(model_files)
}

#' Find Model Path
#'
#' Find the full path to a model file, checking both package models and user paths.
#'
#' @param model_name Character string specifying the model name or path
#' @return Character string with the full path to the model file
#' @export
#' @examples
#' \dontrun{
#' # Find package model
#' path <- find_model_path("kospacing")
#' 
#' # Find user model (returns as-is if file exists)
#' path <- find_model_path("/path/to/my/model.onnx")
#' }
find_model_path <- function(model_name) {
  # If it's already a full path and exists, return it
  if (file.exists(model_name)) {
    return(normalizePath(model_name))
  }
  
  # Try to find in package models
  example_models <- onnx_example_models()
  
  if (model_name %in% names(example_models)) {
    return(example_models[[model_name]])
  }
  
  # Try with .onnx extension
  model_with_ext <- paste0(model_name, ".onnx")
  if (model_with_ext %in% names(example_models)) {
    return(example_models[[model_with_ext]])
  }
  
  # If not found, return original (will cause error in onnx_session)
  return(model_name)
}

#' Create Session with Example Model
#'
#' Convenience function to create a session using an example model.
#'
#' @param model_name Character string specifying the example model name
#' @param providers Optional character vector specifying execution providers
#' @return An RSession object for running inference
#' @export
#' @examples
#' \dontrun{
#' # Create session with example model
#' session <- onnx_example_session("kospacing")
#' 
#' # With specific providers
#' session <- onnx_example_session("kospacing", providers = c("cpu"))
#' }
onnx_example_session <- function(model_name, providers = NULL) {
  model_path <- find_model_path(model_name)
  return(onnx_session(model_path, providers))
}

#' Check ONNX Runtime Availability
#'
#' Check if ONNX Runtime is properly installed and available.
#'
#' @return Logical indicating whether ONNX Runtime is available
#' @export
#' @examples
#' \dontrun{
#' if (check_onnx_runtime_available()) {
#'   cat("ONNX Runtime is available\n")
#' } else {
#'   cat("ONNX Runtime is not available\n")
#' }
#' }
check_onnx_runtime_available <- function() {
  tryCatch({
    models <- onnx_example_models()
    if (length(models) > 0) {
      session <- onnx_session(models[1])
      return(TRUE)
    }
    return(FALSE)
  }, error = function(e) {
    return(FALSE)
  })
}

#' Get ONNX Runtime Information
#'
#' Retrieve information about the ONNX Runtime installation.
#'
#' @return A list containing ONNX Runtime information
#' @export
#' @examples
#' \dontrun{
#' info <- get_onnx_runtime_info()
#' print(info)
#' }
get_onnx_runtime_info <- function() {
  info <- list(
    available = check_onnx_runtime_available(),
    platform = R.version$platform,
    r_version = R.version.string,
    package_version = packageVersion("churon")
  )
  
  # Try to get more detailed info if available
  tryCatch({
    models <- onnx_example_models()
    if (length(models) > 0) {
      session <- onnx_session(models[1])
      providers <- onnx_providers(session)
      info$execution_providers <- providers
      info$example_models <- length(models)
    }
  }, error = function(e) {
    info$error <- e$message
  })
  
  return(info)
}

#' Optimize Session for Performance
#'
#' Configure an ONNX session for optimal performance.
#'
#' @param session An RSession object created by onnx_session()
#' @return The optimized session (invisibly)
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' optimize_session_performance(session)
#' }
optimize_session_performance <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    # Configure session for performance
    session$configure_for_performance()
    
    # Warm up the session
    session$warmup()
    
    message("Session optimized for performance")
    invisible(session)
  }, error = function(e) {
    warning("Failed to optimize session performance: ", e$message)
    invisible(session)
  })
}

#' Get Session Performance Statistics
#'
#' Retrieve performance statistics and memory usage information for a session.
#'
#' @param session An RSession object created by onnx_session()
#' @return A list containing performance statistics
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' stats <- get_session_performance_stats(session)
#' print(stats)
#' }
get_session_performance_stats <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    stats <- session$get_performance_stats()
    
    # Convert to a more R-friendly format
    stats_list <- as.list(stats)
    
    # Add R-specific information
    stats_list$r_session_class <- class(session)
    stats_list$timestamp <- Sys.time()
    
    return(stats_list)
  }, error = function(e) {
    stop("Failed to retrieve performance statistics: ", e$message)
  })
}

#' Estimate Memory Usage
#'
#' Estimate the memory usage of an ONNX session.
#'
#' @param session An RSession object created by onnx_session()
#' @return Estimated memory usage in bytes
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' memory_usage <- estimate_session_memory(session)
#' cat("Estimated memory usage:", memory_usage / (1024^2), "MB\n")
#' }
estimate_session_memory <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    memory_bytes <- session$estimate_memory_usage()
    return(memory_bytes)
  }, error = function(e) {
    stop("Failed to estimate memory usage: ", e$message)
  })
}

#' Batch Process Data
#'
#' Process data in batches for memory efficiency with large datasets.
#'
#' @param session An RSession object created by onnx_session()
#' @param data_list A list of input data to process
#' @param batch_size Number of items to process in each batch
#' @return A list of results from batch processing
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' large_dataset <- list(...)  # Your large dataset
#' results <- batch_process_data(session, large_dataset, batch_size = 32)
#' }
batch_process_data <- function(session, data_list, batch_size = 32) {
  # Validate parameters
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  if (missing(data_list) || !is.list(data_list)) {
    stop("data_list must be a list of input data")
  }
  
  if (!is.numeric(batch_size) || batch_size <= 0) {
    stop("batch_size must be a positive number")
  }
  
  # Process data in batches
  results <- list()
  total_items <- length(data_list)
  
  for (i in seq(1, total_items, by = batch_size)) {
    end_idx <- min(i + batch_size - 1, total_items)
    batch_data <- data_list[i:end_idx]
    
    # Process each item in the batch
    batch_results <- lapply(batch_data, function(item) {
      tryCatch({
        onnx_run(session, item)
      }, error = function(e) {
        warning("Failed to process batch item: ", e$message)
        NULL
      })
    })
    
    results <- c(results, batch_results)
    
    # Progress reporting
    if (interactive()) {
      progress <- round((end_idx / total_items) * 100, 1)
      cat("\rProcessing batch:", end_idx, "/", total_items, "(", progress, "%)")
      if (end_idx == total_items) cat("\n")
    }
  }
  
  return(results)
}

#' Safe ONNX Session Creation
#'
#' Create an ONNX session with automatic error handling and optimization.
#'
#' @param model_path Character string specifying the path to the ONNX model file
#' @param providers Optional character vector specifying execution providers
#' @param optimize Logical indicating whether to optimize the session for performance
#' @return An optimized RSession object or NULL if creation fails
#' @export
#' @examples
#' \dontrun{
#' session <- safe_onnx_session("path/to/model.onnx", optimize = TRUE)
#' if (!is.null(session)) {
#'   # Use the session
#' }
#' }
safe_onnx_session <- function(model_path, providers = NULL, optimize = TRUE) {
  tryCatch({
    # Create the session
    session <- onnx_session(model_path, providers)
    
    # Optimize if requested
    if (optimize) {
      optimize_session_performance(session)
    }
    
    return(session)
  }, error = function(e) {
    warning("Failed to create ONNX session: ", e$message)
    return(NULL)
  })
}

#' Safe ONNX Inference
#'
#' Run ONNX inference with automatic error handling and performance monitoring.
#'
#' @param session An RSession object created by onnx_session()
#' @param inputs A named list of input tensors
#' @param monitor_performance Logical indicating whether to monitor performance
#' @return Inference results or NULL if inference fails
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' inputs <- list(input_tensor = matrix(rnorm(10), nrow = 2, ncol = 5))
#' results <- safe_onnx_run(session, inputs, monitor_performance = TRUE)
#' }
safe_onnx_run <- function(session, inputs, monitor_performance = FALSE) {
  start_time <- if (monitor_performance) Sys.time() else NULL
  
  tryCatch({
    result <- onnx_run(session, inputs)
    
    if (monitor_performance && !is.null(start_time)) {
      elapsed_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
      message("Inference completed in ", round(elapsed_time * 1000, 2), " ms")
    }
    
      return(result)
    }, error = function(e) {
      warning("Inference failed: ", e$message)
      return(NULL)
    })
}

#' ONNX Model Zoo 모델 정보
#'
#' ONNX Model Zoo에서 사용 가능한 모델들의 정보를 반환합니다.
#'
#' @param category 모델 카테고리. 가능한 값:
#'   - "all": 모든 모델 (기본값)
#'   - "vision": 컴퓨터 비전 모델
#'   - "language": 언어 처리 모델
#'   - "other": 기타 모델
#' @return 데이터 프레임 with 모델 정보 (name, url, category, description, input_shape)
#' @export
#' @examples
#' \dontrun{
#' # 모든 모델 리스트
#' models <- onnx_model_zoo_models()
#' print(models)
#'
#' # 비전 모델만
#' vision_models <- onnx_model_zoo_models("vision")
#' }
onnx_model_zoo_models <- function(category = "all") {
  # ONNX Model Zoo 모델 데이터 ( hand-curated list)
  models <- data.frame(
    name = character(0),
    url = character(0),
    category = character(0),
    description = character(0),
    input_shape = character(0),
    stringsAsFactors = FALSE
  )

  # 컴퓨터 비전 모델
  vision_models <- data.frame(
    name = c(
      "mnist",
      "resnet18",
      "resnet50",
      "squeezenet1.0",
      "shufflenet",
      "mobilenet",
      "googlenet",
      "densenet121",
      "inception_v1",
      "inception_v2",
      "efficientnet_lite4",
      "vgg19",
      "alexnet",
      "zfnet512",
      "tiny_yolov2",
      "yolov2",
      "ssd_mobilenet_v1",
      "ssd_resnet34",
      "faster_rcnn",
      "mask_rcnn",
      "deeplab_v3",
      "fcn_resnet50",
      "unet"
    ),
    url = c(
      "https://github.com/onnx/models/raw/main/validated/vision/classification/mnist/model/mnist-8.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/resnet/model/resnet18-v2-7.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/resnet/model/resnet50-v2-7.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/squeezenet/model/squeezenet1.0-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/shufflenet/model/shufflenet-9.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/mobilenet/model/mobilenetv2-7.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/googlenet/model/googlenet-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/densenet/model/densenet121-1.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/inception/model/inception_v1-9.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/inception/model/inception_v2-9.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/efficientnet/model/efficientnet-lite4-11.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/vgg/model/vgg19-7.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/alexnet/model/alexnet-7.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/classification/zfnet512/model/zfnet512-9.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/object_detection/tiny_yolov2/model/tiny_yolov2-7.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/object_detection/yolov2/model/yolov2-voc-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/object_detection/ssd/model/ssd_mobilenet_v1_12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/object_detection/ssd/model/ssd_resnet34_12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/object_detection/faster_rcnn/model/faster_rcnn_resnet50-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/object_detection/mask_rcnn/model/mask_rcnn_resnet50-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/semantic_segmentation/deeplab_v3/model/deeplab_v3_resnet101-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/semantic_segmentation/fcn/model/fcn_resnet50_12.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/semantic_segmentation/unet/model/unet_2d.onnx"
    ),
    category = rep("vision", 23),
    description = c(
      "MNIST 손글씨 숫자 인식 (28x28)",
      "ResNet-18 이미지 분류",
      "ResNet-50 이미지 분류",
      "SqueezeNet 이미지 분류",
      "ShuffleNet 이미지 분류",
      "MobileNetV2 이미지 분류",
      "GoogLeNet 이미지 분류",
      "DenseNet-121 이미지 분류",
      "Inception V1 이미지 분류",
      "Inception V2 이미지 분류",
      "EfficientNet-Lite4 이미지 분류",
      "VGG-19 이미지 분류",
      "AlexNet 이미지 분류",
      "ZFNet 이미지 분류",
      "Tiny YOLOv2 객체 탐지",
      "YOLOv2 객체 탐지",
      "SSD-MobileNetV1 객체 탐지",
      "SSD-ResNet34 객체 탐지",
      "Faster R-CNN 객체 탐지",
      "Mask R-CNN 인스턴스 세그멘테이션",
      "DeepLab V3 세그멘테이션",
      "FCN-ResNet50 세그멘테이션",
      "U-Net 의료 영상 세그멘테이션"
    ),
    input_shape = rep("N x 3 x 224 x 224", 23),
    stringsAsFactors = FALSE
  )

  # 입력 형태 수정
  vision_models$input_shape[vision_models$name == "mnist"] <- "N x 1 x 28 x 28"

  # 언어 처리 모델
  language_models <- data.frame(
    name = c(
      "bert_base",
      "bert_large",
      "distilbert",
      "roberta_base",
      "gpt2",
      "xgboost",
      "lightgbm"
    ),
    url = c(
      "https://github.com/onnx/models/raw/main/validated/nlp/bert_squad/model/bertsquad-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/nlp/bert_squad/model/bertsquad-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/nlp/question_answering/model/distilbert_base_uncased-11.onnx",
      "https://github.com/onnx/models/raw/main/validated/nlp/question_answering/model/roberta_base-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/nlp/text_generation/gpt2/model/gpt2-12.onnx",
      "https://github.com/onnx/models/raw/main/validated/other/xgboost/model/xgboost.onnx",
      "https://github.com/onnx/models/raw/main/validated/other/lightgbm/model/lightgbm.onnx"
    ),
    category = rep("language", 7),
    description = c(
      "BERT-base 질문 응답",
      "BERT-large 질문 응답",
      "DistilBERT 질문 응답",
      "RoBERTa-base 질문 응답",
      "GPT-2 텍스트 생성",
      "XGBoost 분류/회귀",
      "LightGBM 분류/회귀"
    ),
    input_shape = c(
      "N x seq_len",
      "N x seq_len",
      "N x seq_len",
      "N x seq_len",
      "N x seq_len",
      "N x features",
      "N x features"
    ),
    stringsAsFactors = FALSE
  )

  # Other 모델
  other_models <- data.frame(
    name = c(
      "emotion_ferplus",
      "超分辨率"
    ),
    url = c(
      "https://github.com/onnx/models/raw/main/validated/other/emotion_ferplus/model/emotion_ferplus-8.onnx",
      "https://github.com/onnx/models/raw/main/validated/vision/super_resolution/subpixel/model/subpixel_cnn_2016.onnx"
    ),
    category = rep("other", 2),
    description = c(
      "FERPlus 감정 인식 (64x64)",
      "초해상화"
    ),
    input_shape = c("N x 1 x 64 x 64", "N x 1 x 224 x 224"),
    stringsAsFactors = FALSE
  )

  # 모든 모델 결합
  models <- rbind(vision_models, language_models, other_models)

  # 카테고리 필터
  if (category != "all") {
    models <- models[models$category == category, ]
    rownames(models) <- NULL
  }

  models
}

#' ONNX Model Zoo에서 모델 다운로드
#'
#' ONNX Model Zoo에서 모델을 다운로드합니다.
#'
#' @param model_name 모델 이름 (onnx_model_zoo_models()에서 반환된 이름)
#' @param dest_dir 다운로드 디렉토리 (기본값: 현재 디렉토리)
#' @param overwrite 기존 파일 덮어쓰기 (기본값: FALSE)
#' @return 다운로드된 모델 파일 경로
#' @export
#' @examples
#' \dontrun{
#' # MNIST 모델 다운로드
#' model_path <- onnx_download_model("mnist")
#'
#' # 특정 디렉토리에 다운로드
#' model_path <- onnx_download_model("squeezenet1.0", dest_dir = "models/")
#'
#' # 덮어쓰기
#' model_path <- onnx_download_model("mnist", overwrite = TRUE)
#' }
onnx_download_model <- function(model_name, dest_dir = ".", overwrite = FALSE) {
  # 모델 리스트 가져오기
  models <- onnx_model_zoo_models()

  # 모델 찾기
  model_row <- models[models$name == model_name, ]

  if (nrow(model_row) == 0) {
    stop("Model '", model_name, "' not found in ONNX Model Zoo.\n",
         "Use onnx_model_zoo_models() to see available models.")
  }

  url <- model_row$url
  ext <- tools::file_ext(url)
  if (ext == "") ext <- "onnx"

  dest_file <- file.path(dest_dir, paste0(model_name, ".onnx"))

  # 디렉토리 생성
  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
  }

  # 파일이 이미 존재하고 덮어쓰기가 FALSE인 경우
  if (file.exists(dest_file) && !overwrite) {
    message("Model already exists at: ", dest_file)
    return(normalizePath(dest_file))
  }

  # 다운로드
  message("Downloading ", model_name, "...")

  tryCatch({
    # method="auto"가 mac에서 문제를 일으킬 수 있음
    if (.Platform$OS.type == "unix") {
      download.file(url, dest_file, method = "auto", mode = "wb", quiet = TRUE)
    } else {
      download.file(url, dest_file, method = "auto", mode = "wb", quiet = FALSE)
    }

    if (file.exists(dest_file)) {
      message("Downloaded to: ", dest_file)
      return(normalizePath(dest_file))
    } else {
      stop("Download failed - file not created")
    }
  }, error = function(e) {
    stop("Failed to download ", model_name, ": ", e$message)
  })
}

#' 배치로 여러 모델 다운로드
#'
#' ONNX Model Zoo에서 여러 모델을 배치로 다운로드합니다.
#'
#' @param model_names 모델 이름들의 벡터
#' @param dest_dir 다운로드 디렉토리
#' @param overwrite 기존 파일 덮어쓰기
#' @return 다운로드된 파일 경로들의 리스트
#' @export
#' @examples
#' \dontrun{
#' # 여러 모델 다운로드
#' paths <- onnx_download_models(c("mnist", "squeezenet1.0"))
#' }
onnx_download_models <- function(model_names, dest_dir = ".", overwrite = FALSE) {
  if (!is.character(model_names) || length(model_names) == 0) {
    stop("model_names must be a non-empty character vector")
  }

  results <- list()
  for (name in model_names) {
    tryCatch({
      results[[name]] <- onnx_download_model(name, dest_dir, overwrite)
    }, error = function(e) {
      warning("Failed to download ", name, ": ", e$message)
      results[[name]] <- NULL
    })
  }

  invisible(results)
}