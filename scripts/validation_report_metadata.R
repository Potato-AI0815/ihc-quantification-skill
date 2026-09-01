# Shared deterministic metadata for tracked validation reports.
#
# Tracked release-evidence reports must be a pure function of the current
# checkout: the version comes from the VERSION file and the report date from
# the frozen validation metadata file — never from the wall clock — so a
# regeneration on any date reproduces byte-identical tracked reports.
#
# Usage:
#   source(file.path(root, "scripts", "validation_report_metadata.R"))
#   meta <- validation_report_metadata(root)
#   meta$version   # e.g. "2.3.1"
#   meta$date      # e.g. "2026-08-29"

validation_report_metadata <- function(root) {
  version <- trimws(readLines(file.path(root, "VERSION"), warn = FALSE)[1L])
  if (!nzchar(version)) stop("VERSION file is missing or empty.")

  meta_path <- file.path(root, "external_validation", "VALIDATION_METADATA.json")
  meta_text <- paste(readLines(meta_path, warn = FALSE), collapse = "\n")
  match <- regmatches(meta_text, regexpr('"validation_date"\\s*:\\s*"[^"]*"', meta_text))
  if (!length(match)) stop("external_validation/VALIDATION_METADATA.json is missing 'validation_date'.")
  validation_date <- sub('"$', "", sub('"validation_date"\\s*:\\s*"', "", match))
  if (!nzchar(validation_date)) stop("external_validation/VALIDATION_METADATA.json has an empty validation_date.")

  list(version = version, date = validation_date)
}
