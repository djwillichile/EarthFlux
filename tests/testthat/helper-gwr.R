# Data of the GWR test cases (dev/specs/gwr-forcing.md section 10).

# Small case of six stations (G1a-G6): projected coordinates [m], elevation
# [m], air temperature [degC].
gwr_small <- function() {
  list(
    coords = cbind(c(0, 10000, 0, 10000, 20000, 30000),
                   c(0, 0, 10000, 10000, 0, 30000)),
    x = cbind(elevation = c(100, 300, 500, 200, 800, 1200)),
    y = c(20.0, 18.9, 17.5, 19.6, 15.4, 13.1),
    id = paste0("S", 1:6)
  )
}

# Synthetic reference of 150 stations (G7; dev/decisions/gwr-backend.md
# section 2, set.seed(20261104)): 100 km x 100 km domain, elevation = Gaussian
# hill + west-east ramp + noise, distance to the coast = x / 1000 [km], air
# temperature with a lapse rate varying west-east. Restores the RNG state of
# the caller. `grid_side` cells per side of a regular prediction grid.
gwr_synthetic <- function(grid_side = 316L) {
  old <- if (exists(".Random.seed", envir = globalenv())) {
    get(".Random.seed", envir = globalenv())
  }
  on.exit({
    if (is.null(old)) {
      rm(".Random.seed", envir = globalenv())
    } else {
      assign(".Random.seed", old, envir = globalenv())
    }
  })
  set.seed(20261104)
  n <- 150
  l <- 100000
  u <- stats::runif(n, 0, l)
  v <- stats::runif(n, 0, l)
  elev_fun <- function(u, v) {
    1500 * exp(-((u - 0.7 * l)^2 + (v - 0.5 * l)^2) / (2 * (0.25 * l)^2)) +
      200 * (u / l)
  }
  elev <- elev_fun(u, v) + stats::rnorm(n, 0, 30)
  coast <- u / 1000
  b0 <- 22 - 2 * (v / l)
  b1 <- -0.0065 + 0.003 * (u / l - 0.5)
  ta <- b0 + b1 * elev + 0.03 * coast + stats::rnorm(n, 0, 0.4)
  gx <- (seq_len(grid_side) - 0.5) * l / grid_side
  grid <- expand.grid(x = gx, y = gx)
  list(
    coords = cbind(u, v),
    x = cbind(elev = elev, coast = coast),
    y = ta,
    grid_coords = cbind(grid$x, grid$y),
    grid_x = cbind(elev = elev_fun(grid$x, grid$y), coast = grid$x / 1000)
  )
}
