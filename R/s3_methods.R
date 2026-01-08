#' S3 Methods for TensorInfo and RSession
#'
#' These methods provide convenient access to object properties.
#'
#' @param x A TensorInfo or RSession object
#' @param name Property name to access
#' @export
`$.TensorInfo` <- function(x, name) {
  if (name == "name") {
    return(x$get_name())
  } else if (name == "shape") {
    return(x$get_shape())
  } else if (name == "data_type") {
    return(x$get_data_type())
  } else {
    # Try to get the method from the TensorInfo environment
    func <- TensorInfo[[name]]
    if (!is.null(func)) {
      # Create a new environment with self bound to x
      func_env <- new.env(parent = environment(func))
      func_env$self <- x
      environment(func) <- func_env
      return(func)
    }
    return(NULL)
  }
}

#' @export
`[[.TensorInfo` <- `$.TensorInfo`

#' @export
print.TensorInfo <- function(x, ...) {
  cat("TensorInfo:\n")
  cat("  Name:", x$name, "\n")
  cat("  Shape:", paste(x$shape, collapse = " x "), "\n")
  cat("  Data Type:", x$data_type, "\n")
  invisible(x)
}

#' @export
print.RSession <- function(x, ...) {
  cat("ONNX Runtime Session:\n")
  
  tryCatch({
    cat("  Model Path:", x$get_model_path(), "\n")
    
    input_info <- x$get_input_info()
    cat("  Inputs (", length(input_info), "):\n", sep = "")
    for (i in seq_along(input_info)) {
      info <- input_info[[i]]
      cat("    ", info$name, ": ", paste(info$shape, collapse = " x "), 
          " (", info$data_type, ")\n", sep = "")
    }
    
    output_info <- x$get_output_info()
    cat("  Outputs (", length(output_info), "):\n", sep = "")
    for (i in seq_along(output_info)) {
      info <- output_info[[i]]
      cat("    ", info$name, ": ", paste(info$shape, collapse = " x "), 
          " (", info$data_type, ")\n", sep = "")
    }
    
    providers <- x$get_providers()
    cat("  Execution Providers:", paste(providers, collapse = ", "), "\n")
  }, error = function(e) {
    cat("  Error retrieving session information:", e$message, "\n")
  })
  
  invisible(x)
}