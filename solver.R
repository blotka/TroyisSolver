#############################################################################

parse.grid.from.png <- function(file) {

## This function parses a screenshot of a Troyis puzzle
##
## Inputs:
##    - file: a png screenshot of a Troyis puzzle
##
## Output: a list containing:
##    - board: a square matrix of logicals, with TRUE for
##             squares that need to be visited
##    - x.coord: a vector of x.coordinates for all squares
##    - y.coord: a vector of y.coordinates for all squares

   require(png)
   png <- readPNG(file)
   avg <- rowMeans(png[, , 1:3], dim = 2)

   x.rle   <- rle(colMeans(avg) > 0.9)
   y.rle   <- rle(rowMeans(avg) > 0.9)
   x.lines <- cumsum(x.rle$lengths)[x.rle$values]
   y.lines <- cumsum(y.rle$lengths)[y.rle$values]
   x.cells <- round((tail(x.lines, -1) + head(x.lines, -1)) / 2)
   y.cells <- round((tail(y.lines, -1) + head(y.lines, -1)) / 2)

   if(length(x.cells) != length(y.cells)) {
      cat("could not parse a square grid...\n")
      Sys.sleep(2)
      stop("could not parse a square grid...")
   }
   N <- length(x.cells)

   grid <- outer(y.cells, x.cells,
                 FUN = Vectorize(function(i,j)png[i,j,1] > 0.8))
   grid[1, 1] <- TRUE

   return(list(board   = grid,
               x.coord = rep(x.cells, each  = N),
               y.coord = rep(y.cells, times = N)))
}

#############################################################################

solve.board <- function(board) {

## This function finds an optimal (Hamiltonian) path solving
## a given Troyis puzzle.
##
## Inputs:
##    - board: a square matrix of logicals representing a Troyis puzzle,
##             as returned by parse.grid.from.png(file)$board
##
## Output: an integer vector representing the optimal path

   N <- nrow(board)
   P <- board == TRUE
   M <- sum(P)

   # compute adjacency matrix / list of neighbours
   abs.dist.fun  <- function(x, y)abs(x - y)
   row.dist      <- outer(c(row(board)), c(row(board)), abs.dist.fun)
   col.dist      <- outer(c(col(board)), c(col(board)), abs.dist.fun)
   adjacency.mat <- (row.dist == 1L & col.dist == 2L) |
                    (row.dist == 2L & col.dist == 1L)
   adjacency.mat <- adjacency.mat[P, P]
   neighbours    <- lapply(1:M, function(i)which(adjacency.mat[i, ]))

   # a fast version of rowSums
   row.sums <- function(x).Internal(rowSums(x, nrow(x), ncol(x), FALSE))

   # recursive function for building a path of length M
   expand.path <- function(path) {

      Z <- length(path)
      if (Z == M) return(path)

      previous <- path[seq_len(Z - 1L)]
      current  <- path[Z]

      adj <- if (Z == 1L) adjacency.mat else adjacency.mat[, -previous]
      degree <- row.sums(adj)

      # abandon path if there are clues it will never be a solution
      if (Z > 1) {
         next.degree <- degree[-path]
         if (sum(next.degree == 0L) > 0L) return(NULL)
         if (sum(next.degree == 1L) > 1L) return(NULL)
      }

      # find where to go next
      candidates <- neighbours[[current]]
      elected    <- candidates[!candidates %in% path]
      degree     <- row.sums(adj)[elected]

      # branch out
      for (next.one in elected[order(degree)]) {
         res <- expand.path(c(path, next.one))
         if (length(res) > 0L) return(res)
      }
      return(NULL)
   }

   return(which(P)[expand.path(1L)])
}

#############################################################################

write.clicks.script <- function(grid, path, x.start, y.start,
                                sleep.time, script) {

## This function writes an AutoHotkey script (a series of mouse clicks)
## for solving a Troyis puzzle.
##
## Inputs:
##    - grid:       a Troyis grid, as returned by parse.grid.from.png
##    - path:       a solution path, as returned by solve.board
##    - x.start:    x-position of the top-left corner of the screenshot
##                  relative to the screen
##    - y.start:    y-position of the top-left corner of the screenshot
##                  relative to the screen
##    - sleep.time: sleep time (ms) in between clicks
##    - script:     output script filename

   path.x <- grid$x.coord[path]
   path.y <- grid$y.coord[path]

   fh <- file(script, "w")
   pp <- function(...)cat(..., "\n", file = fh)

   pp("CoordMode, Mouse, Screen")
   for (i in tail(seq_along(path.x), -1)) {
      pp("Click", path.x[i] + x.start, ",", path.y[i] + y.start)
      if (sleep.time > 0) pp("Sleep,", sleep.time)
   }

   close(fh)
}

#############################################################################

# This is the main script

args        <- commandArgs(TRUE)
screenshot  <- args[1]
x.start     <- as.integer(args[2])
y.start     <- as.integer(args[3])
sleep.time  <- as.integer(args[4])
output.file <- args[5]

#setwd("C:\Users\Castira\Desktop\hack")
#source("lib\TroyisSolver.R")

grid <- parse.grid.from.png(screenshot)
path <- solve.board(grid$board)
write.clicks.script(grid, path, x.start, y.start, sleep.time, output.file)

