branch <- "main"
onnxruntime_version <- "1.15.1"

#' Install onnxruntime
#'
#' Installs onnxruntime and its dependencies.
#'
#' @param reinstall Re-install onnxruntime even if its already installed?
#' @param ... Currently unused.
#' @param .inform_restart if `TRUE` and running in an `interactive()` session, after
#'   installation it will print a message to inform the user that the session must
#'   be restarted for onnxruntime to work correctly.
#'
#' @details
#' This function is mainly controlled by environment variables that can be used
#' to override the defaults:
#'
#' - `ONNXRUNTIME_HOME`: the installation path. By default dependencies are installed
#'    within the package directory. Eg what's given by `system.file(package="churon")`.
#' - `ONNXRUNTIME_URL`: A URL, path to a ZIP file or a directory containing a Libonnxruntime version.
#'    Files will be installed/copied to the `ONNXRUNTIME_HOME` directory.
#' - `ONNXRUNTIME_INSTALL_DEBUG`: Setting it to 1, shows debug log messages during installation.
#' - `ONNXRUNTIME_COMMIT_SHA`: onnxruntime repository commit sha to be used when querying lantern
#'   uploads. Set it to `'none'` to avoid looking for build for that commit and
#'   use the latest build for the branch.
#'
#' The \code{ONNXRUNTIME_INSTALL} environment
#' variable can be set to \code{0} to prevent auto-installing onnxruntime and \code{ONNXRUNTIME_LOAD} set to \code{0}
#' to avoid loading dependencies automatically. These environment variables are meant for advanced use
#' cases and troubleshooting only.
#' When timeout error occurs during library archive download, or length of downloaded files differ from
#' reported length, an increase of the \code{timeout} value should help.
#'
#' @export
install_onnxruntime <- function(reinstall = FALSE, ..., .inform_restart = TRUE) {
  have_installed <- !onnxruntime_is_installed() || reinstall

  libonnxruntime <- libonnxruntime_url()

  install_lib("onnxruntime", libonnxruntime, reinstall)

  if (.inform_restart && have_installed && interactive()) {
    cli::cli_inform(c(
      v = "onnxruntime dependencies have been installed.",
      i = "You must restart your session to use {.pkg onnxruntime} correctly."
    ))
  }
  set_env()
  return(invisible(TRUE))
}



#' A simple exported version of install_path
#' Returns the onnxruntime installation path.
#' @export
onnxruntime_install_path <- function() {
  normalizePath(inst_path(), mustWork = FALSE)
}

#' Verifies if onnxruntime is installed
#'
#' @export
onnxruntime_is_installed <- function() {
  inst_path <- onnxruntime_install_path()
  lib_is_installed("onnxruntime", onnxruntime_install_path())
}

install_lib <- function(libname, url, reinstall = FALSE) {
  inst_path <- onnxruntime_install_path()
  installer_message(c(
    "We are now proceeding to download and installing lantern and onnxruntime.",
    "The installation path is: {.path {inst_path}}"
  ))

  if (lib_is_installed(libname, inst_path) && !reinstall) {
    installer_message(c(
      "An installation of {.strong {libname}} already exists.",
      "Found file at {.path {inst_path}}."
    ))
    return(invisible(TRUE))
  }

  file_ext <- ".zip"
  uncomp <- utils::unzip
  if (.Platform$OS.type == "unix") {
    file_ext <- ".tgz"
    uncomp <- utils::untar
  }

  # The library URL can be 3 different things:
  # - real URL
  # - path to a zip file containing the library
  # - path to a directory containing the files to be installed.
  if (is_url(url)) {
    tmp <- tempfile(fileext = file_ext)
    file.create(tmp)
    on.exit({file.remove(tmp)}, add = TRUE)

    download.file(url = url, destfile = tmp)
    url <- tmp
  }

  if (grepl(paste0("\\",file_ext,"$"), url) && file.exists(url)) {
    tmp_ex <- tempfile()
    dir.create(tmp_ex)
    on.exit({unlink(tmp_ex)}, add = TRUE)

    uncomp(url, exdir = tmp_ex)
    url <- tmp_ex
  }

  if (dir.exists(url)) {
    # sometimes the extracted dir includes another directory that contains the
    # library within it.
    if (!lib_is_installed(libname, url)) {
      dirs <- list.files(url, full.names = TRUE)
      if (length(dirs) == 1) {
        url <- dirs
      }
    }

    # this where the installation actually happens
    if (lib_is_installed(libname, url)) {
      if (!dir.exists(inst_path)) {
        dir.create(inst_path, recursive = TRUE)
      }

      file.copy(
        from = dir(url, full.names = TRUE),
        to = file.path(inst_path, ""),
        recursive = TRUE
      )
    }
  }

  if (lib_is_installed(libname, inst_path)) {
    return(invisible(TRUE))
  }

  rlang::abort(c(
    "Installation failed.",
    "Could not install {.strong {libname}} from {.val {url}}."
  ))
}

lib_is_installed <- function(libname, install_path) {
  if (file.exists(file.path(install_path, "lib", lib_name(libname))))
    return(TRUE)

  if (file.exists(file.path(install_path, "lib64", lib_name(libname))))
    return(TRUE)

  if (file.exists(file.path(install_path, "bin", lib_name(libname))))
    return(TRUE)

  FALSE
}

inst_path <- function() {
  install_path <- Sys.getenv("ONNXRUNTIME_HOME")
  if (nzchar(install_path)) return(install_path)
  system.file("", package = "churon")
}

libonnxruntime_url <- function() {
  url <- Sys.getenv("ONNXRUNTIME_URL", "")

  if (url != "")
    return(url)

  arch <- architecture()
  if (is_macos()) {
    url <- glue::glue("https://github.com/microsoft/onnxruntime/releases/download/v{onnxruntime_version}/onnxruntime-osx-{arch}-{onnxruntime_version}.tgz")
  }

  if (is_windows()) {
    archw <- "x86"
    if (is_x86_64(arch)) archw <- "x64"
    if (is_arm64(arch)) archw <- "arm64"

    url <- glue::glue("https://github.com/microsoft/onnxruntime/releases/download/v{onnxruntime_version}/onnxruntime-win-{archw}-{onnxruntime_version}.zip")
  }
  if (is_linux()) {
    if (is_x86_64(arch)) archl <- "x64"
    if (is_arm64(arch)) archl <- "aarch64"
    url <- glue::glue("https://github.com/microsoft/onnxruntime/releases/download/v{onnxruntime_version}/onnxruntime-linux-{archl}-{onnxruntime_version}.tgz")
  }

  installer_message(c(
    "Libonnxruntime will be downloaded from:",
    "{.url {url}}"
  ))

  url
}

os_name <- function() {
  os <- Sys.info()["sysname"]
  if (!grepl('windows', os, ignore.case = TRUE)) {
    os
  } else {
    "win64"
  }
}

architecture <- function() {
  arch <- Sys.info()["machine"]

  if (!is_x86_64(arch) && (!is_macos())) {
    cli::cli_abort("Architecture {.val {arch}} is not supported in this OS.")
  }

  if ((!is_arm64(arch)) && (!is_x86_64(arch))) {
    cli::cli_abort("Unsupported architecture {.val {arch}}.")
  }

  installer_message("Architecture is {.val {arch}}")
  arch
}

is_x86_64 <- function(x) {
  x %in% c("x86_64", "x86-64")
}

is_arm64 <- function(x) {
  x %in% c("arm64")
}

is_macos <- function() {
  grepl("darwin", Sys.info()["sysname"], ignore.case = TRUE)
}

is_windows <- function() {
  grepl("windows", Sys.info()["sysname"], ignore.case = TRUE)
}

is_linux <- function() {
  grepl("linux", Sys.info()["sysname"], ignore.case = TRUE)
}

installer_message <- function(msg) {
  if (!is_truthy(Sys.getenv("ONNXRUNTIME_INSTALL_DEBUG", FALSE)))
    return(invisible(msg))
  names(msg) <- rep("i", length(msg))
  cli::cli_inform(msg, class = "onnxruntime_install", .envir = parent.frame())
}

is_truthy <- function(x) {
  if (length(x) == 0) {
    return(FALSE)
  }

  if (length(x) > 1) {
    stop("Unexpected value")
  }

  if (x == "") {
    return(FALSE)
  }

  if (x == "1") {
    return(TRUE)
  }

  (toupper(x) == TRUE)
}

lib_name <- function(name = "onnxruntime") {
  if (.Platform$OS.type == "unix") {
    paste0("lib", name, lib_ext())
  } else {
    paste0(name, lib_ext())
  }
}

lib_ext <- function() {
  if (grepl("darwin", version$os))
    ".dylib"
  else if (grepl("linux", version$os))
    ".so"
  else
    ".dll"
}

is_url <- function(x) {
  grepl("^https", x) || grepl("^http", x)
}

