# Cross-platform path utilities used by command-line entry points.

current_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) != 1L) stop("Run this tool with Rscript so --file is available.")
  normalizePath(path.expand(sub("^--file=", "", file_arg[[1L]])), mustWork = TRUE)
}

is_absolute_path_portable <- function(path) {
  path <- as.character(path)
  grepl("^(?:[A-Za-z]:[/\\\\]|[/\\\\]{2}|/|~(?:[/\\\\]|$))", path, perl = TRUE)
}

normalize_path_portable <- function(path, must_work = FALSE, base_dir = getwd()) {
  if (length(path) != 1L || is.na(path) || !nzchar(path)) stop("Path must be one non-empty value.")
  expanded <- path.expand(as.character(path))
  if (!is_absolute_path_portable(expanded)) expanded <- file.path(base_dir, expanded)
  normalizePath(expanded, mustWork = must_work)
}

resolve_path_portable <- function(path, base_dir, must_work = TRUE) {
  normalize_path_portable(path, must_work = must_work, base_dir = base_dir)
}

normalize_optional_dir <- function(path, create = FALSE, base_dir = getwd()) {
  if (is.null(path) || !nzchar(as.character(path))) return(NULL)
  resolved <- normalize_path_portable(path, must_work = FALSE, base_dir = base_dir)
  if (create) dir.create(resolved, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(resolved)) return(NULL)
  normalizePath(resolved, mustWork = TRUE)
}
