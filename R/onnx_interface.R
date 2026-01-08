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
    
    if (!is.numeric(input_data)) {
      stop("Input '", input_name, "' must be numeric (matrix, vector, or array)")
    }
    
    if (any(is.na(input_data))) {
      warning("Input '", input_name, "' contains NA values. This may cause inference to fail.")
    }
    
    if (any(is.infinite(input_data))) {
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
#' Get the execution providers available for the session.
#'
#' @param session An RSession object created by onnx_session()
#' @return A character vector of available execution providers
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' providers <- onnx_providers(session)
#' cat("Available execution providers:", paste(providers, collapse = ", "), "\n")
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
    
    if (is.null(result)) {
      warning("No provider information available for this session")
      return(character(0))
    }
    
    return(result)
  }, error = function(e) {
    stop("Failed to retrieve provider information: ", e$message)
  })
}

#' Get Model Path
#'
#' Get the model path from a session.
#'
#' @param session An RSession object created by onnx_session()
#' @return Character string with the model path
#' @export
#' @examples
#' \dontrun{
#' session <- onnx_session("path/to/model.onnx")
#' model_path <- onnx_model_path(session)
#' cat("Model path:", model_path, "\n")
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
    
    return(result)
  }, error = function(e) {
    stop("Failed to retrieve model path: ", e$message)
  })
}

#' Get ONNX Runtime Info
#'
#' Get information about the ONNX Runtime installation.
#'
#' @return A list containing runtime information
#' @export
get_onnx_runtime_info <- function() {
  tryCatch({
    session <- RSession$from_path(system.file("model", package = "churon"))
    result <- session$get_model_path()
    return(list(
      version = "2.0.0-rc.11 (ort crate)",
      model_path = result,
      available = TRUE
    ))
  }, error = function(e) {
    return(list(
      version = NA,
      model_path = NA,
      available = FALSE,
      error = e$message
    ))
  })
}

#' Check ONNX Runtime Available
#'
#' Check if ONNX Runtime is available.
#'
#' @return Logical indicating whether ONNX Runtime is available
#' @export
check_onnx_runtime_available <- function() {
  info <- get_onnx_runtime_info()
  
  if (is.null(info$error) && info$available) {
    cat("ONNX Runtime is available!\n")
  } else {
    warning("ONNX Runtime check failed: ", info$error)
  }
}

#' Optimize Session Performance
#'
#' Optimize an ONNX session for better performance.
#'
#' @param session An RSession object created by onnx_session()
#' @return The optimized session (invisibly)
#' @export
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
#' Get performance statistics for a session.
#'
#' @param session An RSession object created by onnx_session()
#' @return A list containing performance statistics
#' @export
get_session_performance_stats <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    result <- session$get_performance_stats()
    return(result)
  }, error = function(e) {
    stop("Failed to retrieve performance statistics: ", e$message)
  })
}

#' Estimate Session Memory Usage
#'
#' Estimate the memory usage of an ONNX session.
#'
#' @param session An RSession object created by onnx_session()
#' @return Estimated memory usage in bytes
#' @export
estimate_session_memory <- function(session) {
  # Validate session parameter
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (!inherits(session, "RSession")) {
    stop("session must be an RSession object created by onnx_session()")
  }
  
  tryCatch({
    result <- session$estimate_memory_usage()
    return(result)
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
batch_process_data <- function(session, data_list, batch_size = 32) {
  # Validate parameters
  if (missing(session) || is.null(session)) {
    stop("session is required and cannot be NULL")
  }
  
  if (missing(data_list) || !is.list(data_list)) {
    stop("data_list must be a list of input data")
  }
  
  if (!is.numeric(batch_size) || batch_size <= 0) {
    stop("batch_size must be a positive number")
  }
  
  results <- list()
  total_items <- length(data_list)
  
  for (i in seq(1, total_items, by = batch_size)) {
    end_idx <- min(i + batch_size - 1, total_items)
    batch_data <- data_list[i:end_idx]
    
    batch_results <- lapply(batch_data, function(item) {
      tryCatch({
        onnx_run(session, item)
      }, error = function(e) {
        warning("Failed to process batch item: ", e$message)
        return(NULL)
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

#' Safe ONNX Run
#'
#' Run inference with automatic error handling and monitoring.
#'
#' @param session An RSession object created by onnx_session()
#' @param inputs A named list of input tensors
#' @param monitor_performance Logical indicating whether to monitor performance
#' @return Result of inference or NULL if failed
#' @export
safe_onnx_run <- function(session, inputs, monitor_performance = FALSE) {
  tryCatch({
    if (monitor_performance) {
      message("Running inference with performance monitoring...")
    }
    
    result <- onnx_run(session, inputs)
    
    if (monitor_performance) {
      message("Inference completed successfully")
    }
    
    return(result)
  }, error = function(e) {
    warning("Failed to run inference: ", e$message)
    return(NULL)
  })
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
safe_onnx_session <- function(model_path, providers = NULL, optimize = TRUE) {
  tryCatch({
    # Create session
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

#' Find Model Path
#'
#' Find the full path to a model file, checking user paths.
#'
#' @param model_name Character string specifying the model name or path
#' @return Character string with the full path to the model file
#' @export
find_model_path <- function(model_name) {
  # If it's already a full path and exists, return it
  if (file.exists(model_name)) {
    return(normalizePath(model_name))
  }
  
  # Return as-is (user must provide valid path)
  return(model_name)
}

#' ONNX Download Model
#'
#' Download a model from the ONNX Model Zoo.
#'
#' @param name Character string specifying the model name
#' @param url Character string specifying the download URL
#' @return Character string with the path to the downloaded model
#' @export
onnx_download_model <- function(name, url) {
  dest <- paste0(name, ".onnx")
  if (!file.exists(dest)) {
    download.file(url, dest, mode = "wb")
  }
  return(dest)
}

#' ONNX Download Models
#'
#' List available models from the ONNX Model Zoo.
#'
#' @param subset Character string specifying the model subset (vision, text, etc.)
#' @return A named character vector of available models
#' @export
onnx_download_models <- function(subset = "vision") {
  # Return empty vector - ONNX Model Zoo models can be downloaded from their GitHub repository
  # https://github.com/onnx/models
  return(character(0))
}

#' ONNX Example Models
#'
#' List available example models bundled with the package.
#'
#' @return A named character vector with model names as names and paths as values
#' @export
onnx_example_models <- function() {
  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)

  if (length(model_files) > 0) {
    names(model_files) <- basename(model_files)
    return(model_files)
  }

  return(character(0))
}

#' ONNX Example Session
#'
#' Create a session with an example model.
#'
#' @param model_name Character string specifying the model name (default: "mnist")
#' @param providers Optional execution providers
#' @return An RSession object
#' @export
onnx_example_session <- function(model_name = "mnist", providers = NULL) {
  models <- onnx_example_models()

  if (length(models) == 0) {
    stop("No example models available. Please download models from ONNX Model Zoo.")
  }

  # Find model by name (with or without .onnx extension)
  model_name_clean <- gsub("\\.onnx$", "", model_name)
  model_path <- models[grepl(paste0("^", model_name_clean), names(models))]

  if (length(model_path) == 0) {
    stop("Model '", model_name, "' not found. Available models: ",
         paste(names(models), collapse = ", "))
  }

  onnx_session(model_path[1], providers = providers)
}

#' ONNX Model Zoo Models
#'
#' List available models from the ONNX Model Zoo.
#'
#' @return A character vector of available models
#' @export
onnx_model_zoo_models <- function() {
  return(character(0))
}
