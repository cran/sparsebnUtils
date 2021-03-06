#
#  s3-sparse.R
#  sparsebnUtils
#
#  Created by Bryon Aragam (local) on 1/22/16.
#  Copyright (c) 2014-2017 Bryon Aragam. All rights reserved.
#

#------------------------------------------------------------------------------#
# sparse S3 Class for R
#------------------------------------------------------------------------------#

#
# An alternative data structure for storing sparse matrices in R using the (row, column, value)
#   format. Internally it is stored as a list with three components, each vectors, that contain
#   the rows / columns / values of the nonzero elements.
#
# Its main purpose is to serve as an intermediary between the standard R dense matrix class and the
#   internal SparseBlockMatrixR class. That is, to convert from matrix to SBM, we do
#
#       matrix -->> sparse -->> SparseBlockMatrixR
#
# In theory, this class can be used externally as a useful data structure for storing sparse matrices
#   as an alternative to the Matrix class provided by the Matrix package. Currently, however, the class
#   structure is fairly limited, so there isn't much a reason to do this.
#
#

#' sparse class
#'
#' Low-level representation of sparse matrices.
#'
#' An alternative data structure for storing sparse matrices in R using the (row, column, value)
#' format. Internally it is stored as a list with three components, each vectors, that contain
#' the rows / columns / values of the nonzero elements.
#'
#' @param x Various \code{R} objects.
#' @param ... (optional) additional arguments.
#'
#' @docType class
#' @name sparse
NULL

#------------------------------------------------------------------------------#
# is.sparse
#
#' @rdname sparse
#' @export
is.sparse <- function(x){
    inherits(x, "sparse")
} # END IS.SPARSE

#' as.sparse
#'
#' Methods for coercing other \code{R} objects to \code{\link{sparse}} objects.
#'
#' @param x A compatible \code{R} object.
#' @param index \code{"R"} or \code{"C"}, depending on whether to use R- or C-style indexing.
#' @param ... other parameters.
#'
#' @return
#' \code{\link{sparse}}
#'
#' @export
as.sparse <- function(x, index = "R", ...){
    sparse(x, index = "R", ...) # NOTE: S3 delegation is implicitly handled by the constructor here
}

#------------------------------------------------------------------------------#
# reIndexC.sparse
#  Re-indexing TO C for sparse objects
#
# #' @describeIn reIndexC C-style re-indexing for \link{sparse} objects.
#' @export
reIndexC.sparse <- function(x){
    if(x$start == 0){
        warning("This object already uses C-style indexing!")
        return(x)
    }

    x$rows <- x$rows - 1
    x$cols <- x$cols - 1
    x$start <- 0

    x
} # END REINDEXC.SPARSE

#------------------------------------------------------------------------------#
# reIndexR.sparse
#  Re-indexing TO R for sparse objects
#
# #' @describeIn reIndexC R-style re-indexing for \link{sparse} objects.
#' @export
reIndexR.sparse <- function(x){
    if(x$start == 1){
        warning("This object already uses R-style indexing!")
        return(x)
    }

    x$rows <- x$rows + 1
    x$cols <- x$cols + 1
    x$start <- 1

    x
} # END REINDEXR.SPARSE

#------------------------------------------------------------------------------#
# sparse.list
#  List constructor
#
#' @export
sparse.list <- function(x, ...){

    if( !is.list(x)){
        stop("Input must be a list!")
    }

    if( length(x) != 5 || any(names(x) != c("rows", "cols", "vals", "dim", "start")) || is.null(names(x))){
        stop("Input is not coercable to an object of type sparse, check list for the following (named) elements: rows, cols, vals, dim, start")
    }

    if( length(unique(lapply(x[1:3], length))) > 1){
        stop("rows / cols / vals elements have different sizes; should all have the same length (pp)!!")
    }

    if(length(x$dim) != 2){
        stop("dim attribute must have length 2!")
    }

    if(x$start != 0 && x$start != 1){
        stop("start attribute must be 0 (C-style) or 1 (R-style)!")
    }

    if(!is.integer(x$rows) || !is.integer(x$cols)){
        stop("rows / cols must both be integers!")
    }

    if(!is.numeric(x$vals)){
        stop("vals must be numeric!")
    }

    structure(x, class = "sparse")
} # END SPARSE.LIST

#------------------------------------------------------------------------------#
# sparse.matrix
#
#' @export
sparse.matrix <- function(x, index = "R", ...){
    matrix_to_sparse(x, index = "R", ...)
} # END SPARSE.MATRIX

#------------------------------------------------------------------------------#
# sparse.Matrix
#
#' @export
sparse.Matrix <- function(x, index = "R", ...){
    Matrix_to_sparse(x, index = "R", ...)
} # END SPARSE.MATRIX

#' @export
sparse.edgeList <- function(x, ...){
    nnode <- num.nodes(x)
    out <- list(rows = c(), cols = c(), vals = c(), dim = c(nnode, nnode), start = 1) # enforce R-style indexing since edgeLists are never passed to C++ (at least for the time being)
    for(j in seq_along(x)){
        child <- j
        parset <- x[[child]] # parent set of j
        out$rows <- c(out$rows, parset) # set parents of child
        out$cols <- c(out$cols, rep(child, length(parset))) # children
    }

    if(length(out$rows) != length(out$cols))
        stop("Error!")

    out$vals <- as.numeric(rep(NA, length(out$cols))) # edgeLists do not carry weight information

    sparse(out)
}

#------------------------------------------------------------------------------#
# as.matrix.sparse
#  Convert FROM sparse TO matrix
#
#' @export
as.matrix.sparse <- function(x, ...){

    if( !is.sparse(x)){
        stop("Input must be a sparse object!")
    }

    if(x$start == 0) x <- reIndexR(x) # if indexing starts at 0, adjust to start 1 instead

    m.dim <- x$dim
    m <- matrix(0, nrow = m.dim[1], ncol = m.dim[2])

    for(k in seq_along(x$vals)){
        m[x$rows[k], x$cols[k]] <- x$vals[k]
    }

    attributes(m)$dim <- x$dim
    # attributes(m)$dimnames <- list()
    rownames(m) <- as.character(1:nrow(m))
    colnames(m) <- as.character(1:ncol(m))

    m
} # END AS.MATRIX.SPARSE

#------------------------------------------------------------------------------#
# as.list.sparse
#  Convert FROM sparse TO list
#
#' @export
as.list.sparse <- function(x, ...){
    list(rows = x$rows, cols = x$cols, vals = x$cols, dim = x$dim, start = x$start)
} # END AS.LIST.SPARSE

#------------------------------------------------------------------------------#
# print.sparse
#  Print function for sparse objects
#  By default, format the output as a three-column matrix [cols | rows | vals] ordered by increasing columns.
#    Optionally, set pretty = FALSE to print the sparse object as a list.
#' @export
print.sparse <- function(x, pretty = TRUE, ...){
    if(pretty){
        out <- cbind(x$cols, x$rows, x$vals)
        colnames(out) <- c("cols", "rows", "vals")
        print(out)
    } else{
        print(as.list(x))
    }

} # END PRINT.SPARSE

#------------------------------------------------------------------------------#
# is.zero.sparse
#  Check to see if a sparse object represents the zero matrix
#
#' @export
is.zero.sparse <- function(x){
    check_if_zero <- (length(x$rows) == 0)

    check_if_zero
} # END IS.ZERO.SPARSE

#------------------------------------------------------------------------------#
# num.nodes.sparse
#
#' @export
num.nodes.sparse <- function(x){
    x$dim[2]
} # NUM.NODES.SPARSE

#------------------------------------------------------------------------------#
# num.edges.sparse
#
#' @export
num.edges.sparse <- function(x){
    ### What to do about this special case...
    # length(x$rows) # Ignores potentially very small edge weights which may be zero

    .num_edges(x)
} # NUM.EDGES.SPARSE

#------------------------------------------------------------------------------#
# t.sparse
#  Take implicit transpose by swapping rows <-> cols
#
#' @export
t.sparse <- function(x){
    temp <- x$rows
    x$rows <- x$cols
    x$cols <- temp

    x
}

#------------------------------------------------------------------------------#
# .num_edges
# Internal function for returning the number of edges in a sparse object
#
.num_edges <- function(x, threshold = FALSE){
    stopifnot(is.sparse(x))

    if(!threshold){
        length(x$rows)
    } else{
        ### Testing only for now
        if(length(which(abs(x$vals) > zero_threshold())) != length(x$rows)){
            stop("Error in .num_edges.sparse! Please check source code.")
        }

        length(which(abs(x$vals) > zero_threshold()))
    }

} # END .NUM_EDGES

matrix_to_sparse <- function(x, index = "R", ...){
    stopifnot(check_if_matrix(x))

    if( nrow(x) != ncol(x)) stop("Input matrix must be square!") # 2-7-15: Why does it need to be square?

    if(index != "R" && index != "C") stop("Invalid entry for index parameter: Must be either 'R' or 'C'!")

    pp <- nrow(x)

    # t1 <- proc.time()[3] ################################################
    nnz <- Matrix::which(is.na(x) | (abs(x) > zero_threshold()), arr.ind = TRUE)
    # t2 <- proc.time()[3] ################################################
    # cat(sprintf("as.sparse nnz via which(...): %f\n", t2-t1))

    ### This is a weird hack that is surprisingly fast:
    ###  Note that the output of which is in the same order as as.vector,
    ###  in the sense that the first element in as.vector(x[x != 0])
    ###  corresponds exactly to the first row of nnz (which is the output
    ###  of which).
    ###
    ### This is _substantially_ faster than either Matrix::Matrix
    ###  and an Rcpp implementation of the loop that was previously used.
    vals <- as.vector(x[x != 0])
    rows <- nnz[, 1]
    cols <- nnz[, 2]

    sp <- sparse.list(list(rows = as.integer(rows), cols = as.integer(cols), vals = as.numeric(vals),
                           dim = c(pp, pp),
                           start = 1
                           )
                      )

    if(index == "R"){
        suppressWarnings(reIndexR(sp))
    } else{
        suppressWarnings(reIndexC(sp))
    }
} # END MATRIX_TO_SPARSE

Matrix_to_sparse <- function(x, index = "R", ...){
    stopifnot(check_if_matrix(x))

    if( nrow(x) != ncol(x)) stop("Input matrix must be square!") # 2-7-15: Why does it need to be square?

    if(index != "R" && index != "C") stop("Invalid entry for index parameter: Must be either 'R' or 'C'!")

    pp <- nrow(x)

    ### If already a Matrix object, just pull out the corresponding slots
    #
    # Tue Jan 12 2021: As of Matrix  1.3-0 (2020-12-15 r3351), this code breaks
    #                   due to a bugfix in the Matrix package. The issue
    #                   according to the Matrix maintainers is that "you call
    #                   a function e.g.
    #                      as(M, "dgTMatrix")  or chol()  or ..
    #                   on such a Matrix but that method does not work, or not
    #                   work as assumed, now that Matrix() does return a
    #                   "ddiMatrix" when it can & unless you explicitly say
    #                   ' doDiag=FALSE '.
    #
    #                   The fix to just say as(x, "TsparseMatrix") instead of
    #                   as(x, "dgTMatrix") below.
    #
    Tx <- as(x, "TsparseMatrix") # needs to be in triplet form, see ?dgCMatrix vs ?dgTMatrix
    vals <- Tx@x
    rows <- Tx@i
    cols <- Tx@j

    sp <- sparse.list(list(rows = as.integer(rows), cols = as.integer(cols), vals = as.numeric(vals),
                           dim = c(pp, pp),
                           start = 0 # NOTE: dgTMatrix uses C-style indexing, so this is different from matrix_to_sparse!
                           )
                      )

    if(index == "R"){
        suppressWarnings(reIndexR(sp))
    } else{
        suppressWarnings(reIndexC(sp))
    }
} # END MATRIX_TO_SPARSE
