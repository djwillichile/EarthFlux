# Tests for the anchor pixel selection (stage [A]): ef_anchor_rule(),
# ef_homogeneity(), ef_anchor_pick(), ef_anchor_criteria(),
# ef_select_anchors() and ef_anchors().
#
# Specification: dev/specs/anchor-pixels.md section 7 (cases P1, P1-q6 and
# S1, determinism, manual = automatic, errors and flags, properties).
# Boundary conditions (stage [B]) are tested in test-anchor-conditions.R.


# Case P1 (section 7.1): 1 x 12 transect.
p1_scene <- function() {
  list(
    lst = c(321, 324, 318, 312, 309, 306, 303, 299, 297, 296, 291, 305),
    ndvi = c(0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90,
             -0.20, NA),
    lai = c(0.1, 0.2, 0.3, 0.8, 1.2, 1.8, 2.5, 4.0, 4.5, 5.0, 0.0, 1.0),
    albedo = c(0.25, 0.40, 0.22, 0.20, 0.19, 0.19, 0.18, 0.18, 0.19, 0.20,
               0.06, 0.20)
  )
}

p1_criteria <- function(quantile_type = 7, cold_lai = 4,
                        cold_pick = ef_anchor_pick("lst", "lowest_fraction",
                                                   0.5)) {
  ef_anchor_criteria(
    cold = list(ef_anchor_rule("ndvi", ">=", 0.75, scale = "percentile"),
                ef_anchor_rule("lai", ">=", cold_lai, scale = "absolute")),
    hot = list(ef_anchor_rule("ndvi", "<=", 0.2, scale = "percentile"),
               ef_anchor_rule("ndvi", ">", 0, scale = "absolute"),
               ef_anchor_rule("albedo", "between", c(0.10, 0.35),
                              scale = "absolute")),
    homogeneity = NULL,
    select = list(cold = cold_pick,
                  hot = ef_anchor_pick("lst", "highest_fraction", 0.5)),
    percentile_domain = "land",
    quantile_type = quantile_type,
    source = "test parameters (dev/specs/anchor-pixels.md 7.1)",
    status = "CANDIDATA"
  )
}

p1_select <- function(scene = p1_scene(), criteria = p1_criteria(), ...) {
  ef_select_anchors(scene$lst, scene$ndvi, scene$albedo, lai = scene$lai,
                    criteria = criteria, aggregate = "mean", ...)
}

# Case S1 (section 7.2): 15 x 15 scene with uniform 5 x 5 cold and hot
# blocks and three traps. `cold_rows`/`cold_cols` move the cold block.
s1_scene <- function(cold_rows = 2:6, cold_cols = 2:6) {
  r <- row(matrix(0, 15, 15))
  c <- col(matrix(0, 15, 15))
  lst <- 300 + (r * 3 + c * 7) %% 11
  ndvi <- 0.30 + ((r + 2 * c) %% 5) * 0.05
  lai <- 1 + ((r + c) %% 4) * 0.5
  albedo <- 0.18 + ((2 * r + c) %% 4) * 0.01
  cold <- r %in% cold_rows & c %in% cold_cols
  dim(cold) <- c(15, 15)
  lst[cold] <- 295
  ndvi[cold] <- 0.85
  lai[cold] <- 5
  albedo[cold] <- 0.20
  hot <- r >= 9 & r <= 13 & c >= 9 & c <= 13
  lst[hot] <- 320
  ndvi[hot] <- 0.10
  lai[hot] <- 0.1
  albedo[hot] <- 0.25
  # (a) isolated cell colder than the cold block, dense vegetation
  lst[13, 3] <- 290; ndvi[13, 3] <- 0.90; lai[13, 3] <- 5.5
  # (b) isolated cell hotter than the hot block, bright (urban)
  lst[3, 13] <- 330; ndvi[3, 13] <- 0.12; lai[3, 13] <- 0.1
  albedo[3, 13] <- 0.45
  # (c) water, colder than everything
  lst[15, 8] <- 285; ndvi[15, 8] <- -0.30; lai[15, 8] <- 0
  albedo[15, 8] <- 0.05
  list(lst = lst, ndvi = ndvi, lai = lai, albedo = albedo)
}

s1_homogeneity <- function(window_na = "exclude") {
  ef_homogeneity("lst", window = 3, stat = "sd", max = 0.5,
                 window_na = window_na)
}

s1_criteria <- function(homogeneity = s1_homogeneity(), cold_lai = 4) {
  ef_anchor_criteria(
    cold = list(ef_anchor_rule("ndvi", ">=", 0.8, scale = "absolute"),
                ef_anchor_rule("lai", ">=", cold_lai, scale = "absolute")),
    hot = list(ef_anchor_rule("ndvi", "<=", 0.15, scale = "absolute"),
               ef_anchor_rule("ndvi", ">", 0, scale = "absolute"),
               ef_anchor_rule("albedo", "between", c(0.10, 0.35),
                              scale = "absolute")),
    homogeneity = homogeneity,
    select = list(cold = ef_anchor_pick("lst", "lowest_fraction", 1),
                  hot = ef_anchor_pick("lst", "highest_fraction", 1)),
    percentile_domain = "land",
    quantile_type = 7,
    source = "test parameters (dev/specs/anchor-pixels.md 7.2)",
    status = "CANDIDATA"
  )
}

s1_select <- function(scene = s1_scene(), criteria = s1_criteria(), ...) {
  ef_select_anchors(scene$lst, scene$ndvi, scene$albedo, lai = scene$lai,
                    criteria = criteria, aggregate = "mean", ...)
}

# terra cell number (row-major) of matrix positions on a 15 x 15 grid
s1_cell <- function(rows, cols) {
  sort(as.integer(outer((rows - 1L) * 15L, cols, "+")))
}

flag_codes <- function(x) vapply(x$flags, `[[`, "", "code")

# Internal statistics ---------------------------------------------------------------

test_that("anchor_quantile() reproduces stats::quantile() for types 1-9", {
  samples <- list(c(0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80,
                    0.90),
                  c(5, 1, 3), 42, c(2, 2, 2, 7, 1, 9, 9, 3))
  probs <- c(0, 0.01, 0.1, 0.2, 0.25, 0.5, 0.75, 0.9, 0.95, 1)
  for (x in samples) {
    for (type in 1:9) {
      expect_equal(anchor_quantile(x, probs, type),
                   quantile(x, probs, type = type, names = FALSE),
                   tolerance = 1e-14)
    }
  }
  expect_identical(anchor_median(c(4, 1, 3, 2)), median(c(4, 1, 3, 2)))
  expect_identical(anchor_median(c(4, 1, 3)), 3)
  expect_identical(anchor_median(c(1, NA)), NA_real_)
  expect_equal(anchor_sd(c(1, 2, 4, 8)), sd(c(1, 2, 4, 8)), tolerance = 1e-14)
  expect_identical(anchor_sd(5), NA_real_)
})

# Criteria constructors -------------------------------------------------------------

test_that("criteria constructors validate their arguments", {
  r <- ef_anchor_rule("ndvi", ">=", 0.95, scale = "percentile")
  expect_s3_class(r, "earthflux_anchor_rule")
  expect_identical(r$value, 0.95)
  expect_error(ef_anchor_rule("ndvi", ">=", 0.95),
               class = "earthflux_missing_input")
  expect_error(ef_anchor_rule("ndvl", ">=", 0.95, scale = "absolute"),
               class = "earthflux_unknown_method")
  expect_error(ef_anchor_rule("ndvi", "=>", 0.95, scale = "absolute"),
               class = "earthflux_unknown_method")
  expect_error(ef_anchor_rule("ndvi", ">=", 1.5, scale = "percentile"),
               class = "earthflux_domain_error")
  expect_error(ef_anchor_rule("ndvi", ">=", 0, scale = "percentile"),
               class = "earthflux_domain_error")
  expect_error(ef_anchor_rule("ndvi", ">=", NA_real_, scale = "absolute"),
               class = "earthflux_input_error")
  expect_error(ef_anchor_rule("ndvi", ">=", c(1, 2), scale = "absolute"),
               class = "earthflux_input_error")
  expect_error(ef_anchor_rule("albedo", "between", c(0.3, 0.1),
                              scale = "absolute"),
               class = "earthflux_input_error")
  expect_error(ef_anchor_rule("land_cover", ">=", 1, scale = "absolute"),
               class = "earthflux_input_error")
  expect_error(ef_anchor_rule("ndvi", "in", 1, scale = "absolute"),
               class = "earthflux_input_error")
  expect_error(ef_anchor_rule("ndvi", ">=", "0.9", scale = "absolute"),
               class = "earthflux_input_error")
  expect_s3_class(ef_anchor_rule("land_cover", "in", c(10, 12),
                                 scale = "absolute"),
                  "earthflux_anchor_rule")

  expect_s3_class(s1_homogeneity(), "earthflux_homogeneity")
  expect_error(ef_homogeneity("lst", window = 4, stat = "sd", max = 1,
                              window_na = "exclude"),
               class = "earthflux_input_error")
  expect_error(ef_homogeneity("lst", window = 1, stat = "sd", max = 1,
                              window_na = "exclude"),
               class = "earthflux_domain_error")
  expect_error(ef_homogeneity("lst", window = 3, stat = "range", max = 1,
                              window_na = "exclude"),
               class = "earthflux_unknown_method")
  expect_error(ef_homogeneity("lst", window = 3, stat = "sd", max = -1,
                              window_na = "exclude"),
               class = "earthflux_domain_error")
  expect_error(ef_homogeneity("lst", window = 3, stat = "sd", max = 1),
               class = "earthflux_missing_input")

  expect_error(ef_anchor_pick("lst", "lowest_fraction", 1.2),
               class = "earthflux_domain_error")
  expect_error(ef_anchor_pick("lst", "lowest", 1.5),
               class = "earthflux_input_error")
  expect_error(ef_anchor_pick("lst", "coldest", 1),
               class = "earthflux_unknown_method")

  crit <- p1_criteria()
  expect_s3_class(crit, "earthflux_anchor_criteria")
  expect_identical(crit$quantile_type, 7L)
  args <- unclass(crit)
  expect_error(do.call(ef_anchor_criteria, args[names(args) != "homogeneity"]),
               class = "earthflux_missing_input")
  bad <- args
  bad$select <- list(cold = args$select$cold)
  expect_error(do.call(ef_anchor_criteria, bad), class = "earthflux_input_error")
  bad <- args
  bad$cold <- args$cold[[1L]]
  expect_error(do.call(ef_anchor_criteria, bad), class = "earthflux_input_error")
  bad <- args
  bad$quantile_type <- 10
  expect_error(do.call(ef_anchor_criteria, bad), class = "earthflux_domain_error")
  bad <- args
  bad$status <- "verified"
  expect_error(do.call(ef_anchor_criteria, bad),
               class = "earthflux_unknown_method")
  bad <- args
  bad$percentile_domain <- NULL
  expect_error(do.call(ef_anchor_criteria, bad),
               class = "earthflux_missing_input")
  expect_output(print(crit), "ndvi >= p0.75")
})

# Case P1 ---------------------------------------------------------------------------

test_that("case P1: percentile thresholds, domain, funnel and anchors", {
  a <- p1_select()
  expect_s3_class(a, "earthflux_anchors")
  expect_identical(a$method, "criteria")
  expect_identical(a$origin, "automatic")

  # Anchors: cold {9, 10}, hot {1}; the coldest cell (water) is not used.
  expect_identical(a$pixels$cell, c(9L, 10L, 1L))
  expect_identical(a$pixels$type, c("cold", "cold", "hot"))
  expect_false(11L %in% a$pixels$cell)

  # Computed thresholds (type 7): Q(0.75) = 0.675, Q(0.2) = 0.19, picks 297
  # and 321.
  th <- a$thresholds
  expect_equal(th$value_lower[th$type == "cold" & th$variable == "ndvi"],
               0.675, tolerance = 1e-12)
  expect_equal(th$value_upper[th$type == "hot" & th$target == "rule" &
                                th$rule == 1L], 0.19, tolerance = 1e-12)
  expect_identical(th$value_upper[th$type == "cold" & th$target == "pick"],
                   297)
  expect_identical(th$value_lower[th$type == "hot" & th$target == "pick"],
                   321)
  expect_identical(unique(th$domain_n[th$scale == "percentile" &
                                        th$target == "rule"]), 10L)
  expect_identical(unique(stats::na.omit(th$quantile_type)), 7L)

  # Funnel: total 12; valid 11; domain 10; cold NDVI 3, LAI 3, selected 2;
  # hot NDVI 3 (incl. water), NDVI > 0 2, albedo 1, selected 1.
  f <- a$funnel
  n_of <- function(type, filter) f$n[f$type == type & f$filter == filter]
  expect_identical(n_of("cold", "total"), 12L)
  expect_identical(n_of("cold", "valid"), 11L)
  expect_identical(n_of("cold", "percentile_domain"), 10L)
  expect_identical(n_of("cold", "ndvi >= p0.75"), 3L)
  expect_identical(n_of("cold", "lai >= 4"), 3L)
  expect_identical(n_of("cold", "selected"), 2L)
  expect_identical(n_of("hot", "ndvi <= p0.2"), 3L)
  expect_identical(n_of("hot", "ndvi > 0"), 2L)
  expect_identical(n_of("hot", "albedo between [0.10, 0.35]"), 1L)
  expect_identical(n_of("hot", "selected"), 1L)

  # One calibration point per class: cold Ts 296.5 K, hot 321 K (24.5 K).
  cp <- a$calibration_points
  expect_identical(cp$type, c("cold", "hot"))
  expect_identical(cp$n_pixels, c(2L, 1L))
  expect_identical(cp$lst, c(296.5, 321))
  expect_equal(cp$ndvi, c(0.85, 0.10), tolerance = 1e-12)
  d <- a$dispersion
  expect_equal(d$sd[d$type == "cold" & d$variable == "lst"], sd(c(297, 296)),
               tolerance = 1e-14)
  expect_identical(d$min[d$type == "cold" & d$variable == "lst"], 296)

  # Flags: single hot pixel only.
  expect_identical(flag_codes(a), "EF_ANCHOR_SINGLE_PIXEL")
  expect_null(a$conditions)
  expect_identical(a$relaxation$type, character(0))
})

test_that("case P1-q6: the quantile type changes the result and is recorded", {
  a <- p1_select(criteria = p1_criteria(quantile_type = 6))
  th <- a$thresholds
  expect_equal(th$value_lower[th$type == "cold" & th$variable == "ndvi"],
               0.725, tolerance = 1e-12)
  expect_identical(th$value_upper[th$type == "cold" & th$target == "pick"],
                   296.5)
  expect_identical(a$pixels$cell[a$pixels$type == "cold"], 10L)
  expect_identical(unique(th$quantile_type[th$scale == "percentile"]), 6L)
  expect_setequal(flag_codes(a), "EF_ANCHOR_SINGLE_PIXEL")
})

test_that("a vector and a 1 x n matrix give the same anchors", {
  s <- p1_scene()
  m <- lapply(s, matrix, nrow = 1)
  a <- p1_select()
  b <- ef_select_anchors(m$lst, m$ndvi, m$albedo, lai = m$lai,
                         criteria = p1_criteria(), aggregate = "mean")
  expect_identical(b$pixels$cell, a$pixels$cell)
  expect_identical(b$pixels$row, c(1L, 1L, 1L))
  expect_identical(b$pixels$col, a$pixels$cell)
  expect_identical(b$calibration_points, a$calibration_points)
  expect_identical(b$funnel, a$funnel)
})

# Case S1 ---------------------------------------------------------------------------

test_that("case S1: homogeneous block interiors are selected, traps are not", {
  s <- s1_scene()
  a <- s1_select(s)
  cold <- a$pixels[a$pixels$type == "cold", ]
  hot <- a$pixels[a$pixels$type == "hot", ]
  expect_identical(cold$cell, s1_cell(3:5, 3:5))
  expect_identical(hot$cell, s1_cell(10:12, 10:12))
  # traps: (13, 3) cold, (3, 13) bright, (15, 8) water
  expect_false(any(c(s1_cell(13, 3), s1_cell(3, 13), s1_cell(15, 8)) %in%
                     a$pixels$cell))
  # rows and columns follow the terra cell order
  expect_identical(cold$row, rep(3:5, each = 3))
  expect_identical(cold$col, rep(3:5, times = 3))
  expect_identical(cold$lst, s$lst[cbind(cold$row, cold$col)])
  expect_true(all(cold$window_stat == 0 & cold$window_complete))
  expect_identical(unique(cold$window_n), 9L)

  # funnel counts computed independently
  f <- a$funnel
  n_of <- function(type, filter) f$n[f$type == type & f$filter == filter]
  expect_identical(n_of("cold", "ndvi >= 0.8"), sum(s$ndvi >= 0.8))
  expect_identical(n_of("cold", "lai >= 4"),
                   sum(s$ndvi >= 0.8 & s$lai >= 4))
  expect_identical(n_of("cold", "homogeneity"), 9L)
  expect_identical(n_of("hot", "ndvi <= 0.15"), sum(s$ndvi <= 0.15))
  expect_identical(n_of("hot", "ndvi > 0"), sum(s$ndvi <= 0.15 & s$ndvi > 0))
  expect_identical(n_of("hot", "albedo between [0.10, 0.35]"),
                   sum(s$ndvi <= 0.15 & s$ndvi > 0 & s$albedo >= 0.10 &
                         s$albedo <= 0.35))
  expect_identical(n_of("hot", "homogeneity"), 9L)

  expect_identical(a$calibration_points$lst, c(295, 320))
  expect_length(a$flags, 0L)
})

test_that("land cover rules select by class codes", {
  s <- s1_scene()
  lc <- matrix(1, 15, 15)
  lc[3:4, 3:5] <- 2
  crit <- s1_criteria()
  crit$cold <- c(crit$cold, list(ef_anchor_rule("land_cover", "in", 2,
                                                scale = "absolute")))
  a <- ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                         land_cover = lc, criteria = crit, aggregate = "mean")
  expect_identical(a$pixels$cell[a$pixels$type == "cold"], s1_cell(3:4, 3:5))
  expect_identical(unique(a$pixels$land_cover[a$pixels$type == "cold"]), 2)
  expect_error(s1_select(s, crit), class = "earthflux_missing_input")
})

# Determinism and ties --------------------------------------------------------------

test_that("the selection is deterministic and leaves the RNG untouched", {
  set.seed(20261104)
  seed <- .Random.seed
  a <- s1_select()
  b <- s1_select()
  expect_identical(.Random.seed, seed)
  for (nm in c("pixels", "calibration_points", "thresholds", "funnel",
               "flags", "search", "dispersion")) {
    expect_identical(a[[nm]], b[[nm]])
  }
  expect_null(a$provenance$seed)
})

test_that("ties at the pick limit are resolved by cell number and flagged", {
  s <- p1_scene()
  s$lst[9] <- 296 # cells 9 and 10 now share the lowest cold temperature
  crit <- p1_criteria(cold_pick = ef_anchor_pick("lst", "lowest", 1))
  a <- p1_select(s, crit)
  expect_identical(a$pixels$cell[a$pixels$type == "cold"], 9L)
  expect_true("EF_ANCHOR_TIES" %in% flag_codes(a))

  b <- p1_select(criteria = crit)
  expect_identical(b$pixels$cell[b$pixels$type == "cold"], 10L)
  expect_false("EF_ANCHOR_TIES" %in% flag_codes(b))
  # fraction picks keep every tied cell: no tie to resolve
  c <- p1_select(s)
  expect_false("EF_ANCHOR_TIES" %in% flag_codes(c))
})

# Explicit anchors ------------------------------------------------------------------

test_that("manual anchors with the automatic cells reproduce the audit table", {
  s <- s1_scene()
  a <- s1_select(s, origin = c(500000, 6300000), cell_size = 1000,
                 crs = "EPSG:32719")
  m <- ef_anchors(cold = a$pixels$cell[a$pixels$type == "cold"],
                  hot = a$pixels$cell[a$pixels$type == "hot"],
                  lst = s$lst, ndvi = s$ndvi, albedo = s$albedo, lai = s$lai,
                  homogeneity = s1_homogeneity(), aggregate = "mean",
                  origin = c(500000, 6300000), cell_size = 1000,
                  crs = "EPSG:32719", note = "copy of the automatic cells")
  expect_identical(m$pixels, a$pixels)
  expect_identical(m$calibration_points, a$calibration_points)
  expect_identical(m$method, "manual")
  expect_identical(m$origin, "user")
  expect_null(m$criteria)
  expect_identical(m$note, "copy of the automatic cells")

  # coordinates of the cell centres are equivalent to cell numbers
  xy <- m$pixels[, c("x", "y")]
  expect_identical(xy$x[1L], 500000 + 2.5 * 1000)
  expect_identical(xy$y[1L], 6300000 - 2.5 * 1000)
  mc <- ef_anchors(cold = as.matrix(xy[m$pixels$type == "cold", ]),
                   hot = xy[m$pixels$type == "hot", ],
                   lst = s$lst, ndvi = s$ndvi, albedo = s$albedo, lai = s$lai,
                   homogeneity = s1_homogeneity(), aggregate = "mean",
                   origin = c(500000, 6300000), cell_size = 1000,
                   crs = "EPSG:32719", note = "copy of the automatic cells")
  expect_identical(mc$pixels, m$pixels)
  expect_identical(as.data.frame(mc), mc$pixels)
})

test_that("flags derived from the origin match the provenance (R19)", {
  s <- s1_scene()
  a <- s1_select(s)
  m <- ef_anchors(cold = 33, hot = 160, lst = s$lst, ndvi = s$ndvi,
                  albedo = s$albedo, aggregate = "none")
  for (x in list(a, m)) {
    expect_identical("EF_ANCHOR_USER_SUPPLIED" %in% flag_codes(x),
                     x$origin == "user")
  }
  f <- m$flags[[match("EF_ANCHOR_USER_SUPPLIED", flag_codes(m))]]
  expect_identical(f$scope, "object")
  expect_identical(f$n_total, 1L)
  expect_true("EF_ANCHOR_SINGLE_PIXEL" %in% flag_codes(m))
  expect_true("EF_ANCHOR_USER_SUPPLIED" %in% m$provenance$flags$evaluated)
})

test_that("cell numbers follow the terra (row-major) order", {
  lst <- matrix(c(300, 301, 299, 320,
                  298, 300, 302, 322,
                  297, 301, 300, 321), nrow = 3, byrow = TRUE)
  ndvi <- matrix(0.5, 3, 4)
  albedo <- matrix(0.2, 3, 4)
  m <- ef_anchors(cold = 9, hot = 8, lst = lst, ndvi = ndvi, albedo = albedo,
                  aggregate = "none")
  expect_identical(m$pixels$row, c(3L, 2L))
  expect_identical(m$pixels$col, c(1L, 4L))
  expect_identical(m$pixels$lst, c(297, 322))
})

test_that("explicit anchors are validated", {
  s <- s1_scene()
  base <- list(lst = s$lst, ndvi = s$ndvi, albedo = s$albedo,
               aggregate = "mean")
  call_anchors <- function(...) do.call(ef_anchors, c(list(...), base))
  hot_cells <- s1_cell(10:12, 10:12)
  cold_cells <- s1_cell(3:5, 3:5)

  e <- expect_error(call_anchors(cold = hot_cells, hot = cold_cells),
                    class = "earthflux_anchor_inverted")
  expect_s3_class(e, "earthflux_anchor_error")
  expect_identical(e$lst_cold, 320)
  expect_identical(e$lst_hot, 295)

  e <- expect_error(call_anchors(cold = c(cold_cells, 226), hot = hot_cells),
                    class = "earthflux_anchor_outside_grid")
  expect_identical(e$index, 10L)
  expect_s3_class(e, "earthflux_input_error")
  expect_error(call_anchors(cold = 0, hot = hot_cells),
               class = "earthflux_anchor_outside_grid")

  lst_na <- s$lst
  lst_na[4, 4] <- NA
  e <- expect_error(
    ef_anchors(cold = cold_cells, hot = hot_cells, lst = lst_na,
               ndvi = s$ndvi, albedo = s$albedo, aggregate = "mean"),
    class = "earthflux_anchor_na_input"
  )
  expect_identical(e$variable, "lst")
  expect_identical(e$index, s1_cell(4, 4))

  expect_error(call_anchors(cold = cold_cells, hot = c(hot_cells, 49)),
               class = "earthflux_input_error")
  expect_error(call_anchors(cold = c(33, 33), hot = hot_cells),
               class = "earthflux_input_error")
  expect_error(call_anchors(cold = 33.5, hot = hot_cells),
               class = "earthflux_input_error")
  expect_error(call_anchors(cold = cbind(1, 2), hot = hot_cells),
               class = "earthflux_missing_input")
  expect_error(
    ef_anchors(cold = cbind(0, 0), hot = hot_cells, lst = s$lst,
               ndvi = s$ndvi, albedo = s$albedo, aggregate = "mean",
               origin = c(100, 100), cell_size = 10, crs = "local"),
    class = "earthflux_anchor_outside_grid"
  )
  expect_error(call_anchors(cold = cold_cells),
               class = "earthflux_missing_input")
  expect_error(
    ef_anchors(cold = cold_cells, hot = hot_cells, lst = s$lst,
               ndvi = s$ndvi, albedo = s$albedo),
    class = "earthflux_missing_input"
  )
  expect_error(
    ef_anchors(cold = cold_cells, hot = hot_cells, lst = s$lst,
               ndvi = s$ndvi, albedo = s$albedo, aggregate = "none"),
    class = "earthflux_input_error"
  )
})

# Errors of the automatic selection -------------------------------------------------

test_that("no candidates raises a classed error with the funnel", {
  e <- expect_error(p1_select(criteria = p1_criteria(cold_lai = 6)),
                    class = "earthflux_anchor_no_candidates")
  expect_s3_class(e, "earthflux_anchor_error")
  expect_identical(e$type, "cold")
  f <- e$funnel[e$funnel$type == "cold", ]
  expect_identical(f$n[f$filter == "lai >= 6"], 0L)
  expect_match(conditionMessage(e), "lai >= 6", fixed = TRUE)
  expect_true(is.data.frame(e$thresholds))

  s <- p1_scene()
  s$albedo[] <- 0.5
  e <- expect_error(p1_select(s, p1_criteria(cold_lai = 6)),
                    class = "earthflux_anchor_no_candidates")
  expect_identical(e$type, "both")
})

test_that("an empty percentile domain raises a classed error", {
  s <- p1_scene()
  e <- expect_error(p1_select(s, qa = rep(FALSE, 12)),
                    class = "earthflux_anchor_insufficient_domain")
  expect_s3_class(e, "earthflux_anchor_error")
  expect_identical(e$type, "both")
})

test_that("an inverted automatic selection raises earthflux_anchor_inverted", {
  s <- p1_scene()
  s$lst[1] <- 290 # the only hot anchor becomes colder than the cold ones
  e <- expect_error(p1_select(s), class = "earthflux_anchor_inverted")
  expect_identical(e$lst_hot, 290)
  expect_identical(e$lst_cold, 296.5)
})

test_that("inputs of the automatic selection are validated", {
  s <- p1_scene()
  crit <- p1_criteria()
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                                 aggregate = "mean"),
               class = "earthflux_missing_input")
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                                 criteria = crit),
               class = "earthflux_missing_input")
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                                 criteria = list(), aggregate = "mean"),
               class = "earthflux_input_error")
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, criteria = crit,
                                 aggregate = "mean"),
               class = "earthflux_missing_input")
  expect_error(ef_select_anchors(s$lst, s$ndvi[-1], s$albedo, lai = s$lai,
                                 criteria = crit, aggregate = "mean"),
               class = "earthflux_input_error")
  bad <- s$ndvi
  bad[3] <- 1.2
  expect_error(ef_select_anchors(s$lst, bad, s$albedo, lai = s$lai,
                                 criteria = crit, aggregate = "mean"),
               class = "earthflux_domain_error")
  bad <- s$lst
  bad[3] <- -1
  expect_error(ef_select_anchors(bad, s$ndvi, s$albedo, lai = s$lai,
                                 criteria = crit, aggregate = "mean"),
               class = "earthflux_domain_error")
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                                 criteria = crit, aggregate = "mean",
                                 qa = c(NA, rep(TRUE, 11))),
               class = "earthflux_input_error")
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                                 criteria = crit, aggregate = "none"),
               class = "earthflux_input_error")
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                                 criteria = crit, aggregate = "mode"),
               class = "earthflux_unknown_method")
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                                 criteria = crit, aggregate = "mean",
                                 relax = crit),
               class = "earthflux_input_error")
  # a homogeneity test needs matrix layers
  crit_h <- p1_criteria()
  crit_h$homogeneity <- s1_homogeneity()
  expect_error(ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                                 criteria = crit_h, aggregate = "mean"),
               class = "earthflux_input_error")
  m <- s1_scene()
  expect_error(ef_select_anchors(m$lst, m$ndvi, t(m$albedo[1:14, ]),
                                 lai = m$lai, criteria = s1_criteria(),
                                 aggregate = "mean"),
               class = "earthflux_input_error")
  expect_error(ef_select_anchors(m$lst, m$ndvi, m$albedo, lai = m$lai,
                                 criteria = s1_criteria(), aggregate = "mean",
                                 station = c(1, 1)),
               class = "earthflux_input_error")
})

# Relaxation, staged search and their flags -----------------------------------------

test_that("criteria are relaxed only with an explicit plan, and flagged", {
  strict <- p1_criteria(cold_lai = 6)
  expect_error(p1_select(criteria = strict),
               class = "earthflux_anchor_no_candidates")
  a <- p1_select(criteria = strict, relax = list(p1_criteria()))
  expect_identical(a$pixels$cell, c(9L, 10L, 1L))
  expect_true("EF_ANCHOR_CRITERIA_RELAXED" %in% flag_codes(a))
  expect_identical(a$relaxation$type, "cold")
  expect_identical(a$relaxation$step, 2L)
  expect_identical(a$criteria$step_used, c(cold = 2L, hot = 1L))
  # the funnel keeps the failed attempt
  expect_identical(sort(unique(a$funnel$step[a$funnel$type == "cold"])),
                   c(1L, 2L))
  expect_false("EF_ANCHOR_HOMOGENEITY_DROPPED" %in% flag_codes(a))
  expect_output(print(a), "Relaxation steps used")

  b <- p1_select()
  expect_false("EF_ANCHOR_CRITERIA_RELAXED" %in% flag_codes(b))
})

test_that("dropping the homogeneity test in a relaxation step is flagged", {
  strict <- s1_criteria(cold_lai = 9)
  relaxed <- s1_criteria(homogeneity = NULL)
  a <- s1_select(criteria = strict, relax = list(relaxed))
  expect_true(all(c("EF_ANCHOR_CRITERIA_RELAXED",
                    "EF_ANCHOR_HOMOGENEITY_DROPPED") %in% flag_codes(a)))
  # without homogeneity the isolated trap (a) becomes a cold anchor
  expect_true(s1_cell(13, 3) %in% a$pixels$cell)
  expect_true(all(is.na(a$pixels$window_stat[a$pixels$type == "cold"])))
  expect_true(all(a$pixels$window_stat[a$pixels$type == "hot"] == 0))
})

test_that("a staged search records where each class was found", {
  s <- s1_scene()
  south <- row(s$lst) >= 8
  a <- s1_select(s, search_area = list(south, matrix(TRUE, 15, 15)))
  expect_identical(a$search$used$stage, c(2L, 1L))
  expect_true("EF_ANCHOR_SEARCH_EXPANDED" %in% flag_codes(a))
  expect_identical(a$pixels$cell[a$pixels$type == "cold"], s1_cell(3:5, 3:5))
  expect_identical(a$search$stages$n_cells, c(sum(south), 225L))

  b <- s1_select(s, search_area = matrix(TRUE, 15, 15))
  expect_false("EF_ANCHOR_SEARCH_EXPANDED" %in% flag_codes(b))
  expect_identical(b$pixels, s1_select(s)$pixels)
})

# Homogeneity windows -----------------------------------------------------------------

test_that("incomplete homogeneity windows are excluded or flagged", {
  s <- s1_scene(cold_rows = 1:3, cold_cols = 1:3)
  a <- s1_select(s, criteria = s1_criteria(s1_homogeneity("exclude")))
  expect_identical(a$pixels$cell[a$pixels$type == "cold"], s1_cell(2, 2))
  expect_false("EF_ANCHOR_WINDOW_INCOMPLETE" %in% flag_codes(a))

  b <- s1_select(s, criteria = s1_criteria(s1_homogeneity("available")))
  cold <- b$pixels[b$pixels$type == "cold", ]
  expect_identical(cold$cell, s1_cell(1:2, 1:2))
  expect_identical(cold$window_n_valid, c(4L, 6L, 6L, 9L))
  expect_identical(cold$window_complete, c(FALSE, FALSE, FALSE, TRUE))
  f <- b$flags[[match("EF_ANCHOR_WINDOW_INCOMPLETE", flag_codes(b))]]
  expect_identical(f$scope, "record")
  expect_identical(f$index, cold$id[!cold$window_complete])
  expect_identical(f$n_total, nrow(b$pixels))

  # a user-supplied anchor at the border is audited the same way
  m <- ef_anchors(cold = 1, hot = s1_cell(11, 11), lst = s$lst,
                  ndvi = s$ndvi, albedo = s$albedo,
                  homogeneity = s1_homogeneity("exclude"), aggregate = "none")
  expect_identical(m$pixels$window_complete, c(FALSE, TRUE))
  f <- m$flags[[match("EF_ANCHOR_WINDOW_INCOMPLETE", flag_codes(m))]]
  expect_identical(f$index, 1L)

  # missing cells inside the window also make it incomplete
  s2 <- s1_scene()
  s2$lst[11, 12] <- NA
  m2 <- ef_anchors(cold = s1_cell(4, 4), hot = s1_cell(11, 11), lst = s2$lst,
                   ndvi = s2$ndvi, albedo = s2$albedo,
                   homogeneity = s1_homogeneity("exclude"),
                   aggregate = "none")
  expect_identical(m2$pixels$window_n_valid, c(9L, 8L))
  expect_true("EF_ANCHOR_WINDOW_INCOMPLETE" %in% flag_codes(m2))
})

# Overpass time, inherited flags, station ------------------------------------------

test_that("different overpass times within a class are flagged", {
  s <- s1_scene()
  hour <- matrix(15.2, 15, 15)
  a <- s1_select(s, utc_hour = hour)
  expect_false("EF_ANCHOR_OVERPASS_SPREAD" %in% flag_codes(a))
  expect_identical(a$calibration_points$utc_hour, c(15.2, 15.2))
  hour[4, 4] <- 15.3
  b <- s1_select(s, utc_hour = hour)
  expect_true("EF_ANCHOR_OVERPASS_SPREAD" %in% flag_codes(b))
  d <- b$dispersion
  expect_identical(d$max[d$type == "cold" & d$variable == "utc_hour"], 15.3)
  expect_error(s1_select(s, utc_hour = hour + 10),
               class = "earthflux_domain_error")
})

test_that("upstream cell flags are inherited by the anchor pixels", {
  s <- s1_scene()
  mask <- matrix(FALSE, 15, 15)
  mask[3, 4] <- TRUE # R position 48 (column-major), terra cell 34
  up <- list(ef_flag(mask, "EF_INPUT_NA", scope = "cell"))
  a <- s1_select(s, inherited_flags = up)
  expect_identical(a$pixels$inherited_flags[a$pixels$cell == 34L],
                   "EF_INPUT_NA")
  expect_true(all(a$pixels$inherited_flags[a$pixels$cell != 34L] == ""))
  expect_identical(a$provenance$flags$inherited$code, "EF_INPUT_NA")
  expect_identical(a$provenance$flags$inherited$id,
                   a$pixels$id[a$pixels$cell == 34L])
  # inherited codes are not re-raised as EF_ANCHOR_* codes
  expect_false(any(grepl("^EF_INPUT", flag_codes(a))))
  wrong <- list(ef_flag(c(TRUE, FALSE), "EF_INPUT_NA", scope = "cell"))
  expect_error(s1_select(s, inherited_flags = wrong),
               class = "earthflux_input_error")
})

test_that("coordinates, distance to a station and window size are recorded", {
  a <- s1_select(origin = c(0, 15000), cell_size = 1000, crs = "local",
                 station = c(3500, 11500))
  cold <- a$pixels[a$pixels$type == "cold", ]
  expect_identical(cold$x[1L], 2500)
  expect_identical(cold$y[1L], 12500)
  expect_equal(cold$distance_to_station[1L], sqrt(1000^2 + 1000^2),
               tolerance = 1e-12)
  expect_identical(a$search$window_m, c(cold = 3000, hot = 3000))
  expect_identical(a$grid$crs, "local")
})

# Properties ------------------------------------------------------------------------

test_that("water, missing cells and unused variables do not change anchors", {
  ref <- p1_select()
  s <- p1_scene()
  s2 <- lapply(s, function(x) c(x, NA))
  s2$lst[13] <- 280
  s2$ndvi[13] <- -0.5
  s2$albedo[13] <- 0.05
  s2$lai[13] <- 0
  s2 <- lapply(s2, function(x) c(x, NA))
  s2$lst[14] <- 300
  a <- p1_select(s2)
  expect_identical(a$pixels$cell, ref$pixels$cell)
  expect_identical(a$calibration_points, ref$calibration_points)

  # elevation is recorded but not used by the selection
  b <- p1_select(elevation = seq(100, 1200, by = 100))
  expect_identical(b$pixels$cell, ref$pixels$cell)
  expect_identical(b$calibration_points$elevation, c(950, 100))

  # values outside the search area are irrelevant
  sc <- s1_scene()
  area <- matrix(TRUE, 15, 15)
  area[14:15, ] <- FALSE
  ref2 <- s1_select(sc, search_area = area)
  sc$lst[15, 1:4] <- 340
  sc$ndvi[15, 1:4] <- 0.05
  sc$albedo[15, 1:4] <- 0.25
  # (the anchors do not change; the scene-wide ranks of the audit table do)
  out <- s1_select(sc, search_area = area)
  expect_identical(out$pixels$cell, ref2$pixels$cell)
  expect_identical(out$calibration_points, ref2$calibration_points)
})

test_that("calibration points use the explicit aggregate", {
  s <- s1_scene()
  s$lst[4, 4] <- 295.2 # keeps sd(window) under 0.5 K
  a <- s1_select(s)
  m <- ef_select_anchors(s$lst, s$ndvi, s$albedo, lai = s$lai,
                         criteria = s1_criteria(), aggregate = "median")
  cold_lst <- a$pixels$lst[a$pixels$type == "cold"]
  expect_identical(a$calibration_points$lst[1L], mean(cold_lst))
  expect_identical(m$calibration_points$lst[1L], median(cold_lst))
  expect_identical(m$calibration_points$aggregate, c("median", "median"))
})

test_that("print() summarises the anchor set", {
  expect_output(print(p1_select()), "cold +2 pixel\\(s\\), Ts = 296.50 K")
  expect_output(print(p1_select()), "EF_ANCHOR_SINGLE_PIXEL")
})

# Flag registry -----------------------------------------------------------------------

test_that("the anchor stage registers only the class I codes it raises", {
  rows <- ef_flags_anchors()
  expect_setequal(rows$code, c(
    "EF_ANCHOR_USER_SUPPLIED", "EF_ANCHOR_CRITERIA_RELAXED",
    "EF_ANCHOR_SEARCH_EXPANDED", "EF_ANCHOR_HOMOGENEITY_DROPPED",
    "EF_ANCHOR_WINDOW_INCOMPLETE", "EF_ANCHOR_TIES", "EF_ANCHOR_SINGLE_PIXEL",
    "EF_ANCHOR_COLD_H_NEGATIVE", "EF_ANCHOR_HOT_LE_ASSUMED_ZERO",
    "EF_ANCHOR_OVERPASS_SPREAD"
  ))
  expect_true(all(is.na(rows$bit)))
  sev <- stats::setNames(rows$severity, rows$code)
  expect_identical(unname(sev[c("EF_ANCHOR_CRITERIA_RELAXED",
                                "EF_ANCHOR_WINDOW_INCOMPLETE",
                                "EF_ANCHOR_COLD_H_NEGATIVE")]),
                   rep("warning", 3L))
  expect_identical(unname(sev[c("EF_ANCHOR_TIES", "EF_ANCHOR_USER_SUPPLIED")]),
                   rep("info", 2L))
  scope <- stats::setNames(rows$scope, rows$code)
  expect_identical(unname(scope[c("EF_ANCHOR_WINDOW_INCOMPLETE",
                                  "EF_ANCHOR_COLD_H_NEGATIVE")]),
                   c("record", "record"))
  class_ii <- c("EF_ANCHOR_FEW_CANDIDATES", "EF_ANCHOR_CONTRAST_LOW",
                "EF_ANCHOR_COLD_PARTIAL_COVER", "EF_ANCHOR_HOT_RECENT_RAIN",
                "EF_ANCHOR_SMALL_CONTRAST", "EF_ANCHOR_DT_SMALL",
                "EF_ANCHOR_QA_DEGRADED", "EF_ANCHOR_HIGH_VIEW_ANGLE",
                "EF_ANCHOR_COMPOSITE_LAG", "EF_ANCHOR_FORCING_EXTRAPOLATED")
  expect_identical(intersect(ef_flag_registry()$code, class_ii), character(0))
})
