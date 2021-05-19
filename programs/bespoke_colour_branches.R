
ali_branch <-   function (dend, k = NULL, h = NULL, col, groupLabels = NULL, 
          clusters, warn = dendextend_options("warn"), ...) 
{
  get_col <- function(col, k) {
    if (is.function(col)) {
      col <- col(k)
    }
    else {
      if (length(col) < k) {
        warning("Length of color vector was shorter than the number of clusters - color vector was recycled")
        col <- rep(col, length.out = k)
      }
      if (length(col) > k) {
        warning("Length of color vector was longer than the number of clusters - first k elements are used")
        col <- col[seq_len(k)]
      }
    }
    return(col)
  }
  
  if (missing(col)) 
    col <- rainbow_fun
  if (!missing(clusters)) {
    if (!missing(k)) 
      warning("Both the parameters 'cluster' and 'k' are not missing - k is ignored.")
    if (length(clusters) != nleaves(dend)) {
      warning("'clusters' is not of the same length as the number of labels. The dend is returned as is.")
      return(dend)
    }
    u_clusters <- unique(clusters)
    k <- length(u_clusters)
    col <- get_col(col, k)
    return(branches_attr_by_clusters(dend, clusters, values = col, 
                                     attr = "col", branches_changed_have_which_labels = "all"))
  }
  old_labels <- labels(dend)
  labels_arent_unique <- !all_unique(old_labels)
  if (labels_arent_unique) {
    if (warn) 
      warning("Your dend labels are NOT unique!\n This may cause an un expected issue with the color of the branches.\n Hence, your labels were temporarily turned unique (and then fixed as they were before).")
    labels(dend) <- seq_along(old_labels)
  }
  if (is.null(k) & is.null(h)) {
    if (warn) 
      warning("k (number of clusters) is missing, using the dend size as a default")
    k <- nleaves(dend)
  }
  if (!is.dendrogram(dend) && !is.hclust(dend)) 
    stop("dend needs to be either a dendrogram or an hclust object")
  g <- dendextend::cutree(dend, k = k, h = h, order_clusters_as_data = FALSE)
  if (is.hclust(dend)) 
    dend <- as.dendrogram(dend)
  k <- max(g)
  if (k == 0L) {
    if (warn) 
      warning("dend has only one level - returning the dendrogram with no colors.")
    return(dend)
  }
  col_old <- get_col(col, k)
  k_above_h <- length(unique(g[duplicated(g)]))
  col_above_h <- get_col(col, k_above_h)
  if (!is.null(groupLabels)) {
    if (length(groupLabels) == 1) {
      if (is.function(groupLabels)) {
        groupLabels <- groupLabels(seq.int(length.out = k))
      }
      else if (is.logical(groupLabels)) {
        if (groupLabels) {
          groupLabels <- seq.int(length.out = k)
        }
        else {
          groupLabels <- NULL
        }
      }
    }
    if (!is.null(groupLabels) && length(groupLabels) != k) {
      stop("Must give same number of group labels as clusters")
    }
  }
  addcol <- function(dend_node, col, lab) {
    if (is.null(attr(dend_node, "edgePar"))) {
      attr(dend_node, "edgePar") <- list(col = col, p.border = col)
    }
    else {
      if(attr(dend_node, "height") <= h){
        attr(dend_node, "edgePar")[["col"]] <- col
        attr(dend_node, "edgePar")[["p.border"]] <- col
      }
    }
    if (is.null(attr(dend_node, "nodePar"))) {
      attr(dend_node, "nodePar") <- list(lab.col = col, pch = NA)
    }
    else {
      if(attr(dend_node, "height") <= h){
        attr(dend_node, "nodePar")[["lab.col"]] <- col
        #attr(dend_node, "edgetext") <- round(attr(dend_node, "height"), 2)
      }
    }
    unclass(dend_node)
  }
  
descendTree <- function(sd) {
    groupsinsubtree <- unique(g[labels(sd)])
    if (length(groupsinsubtree) > 1) {
      for (i in seq(sd)) {
        sd[[i]] <- descendTree(sd[[i]])
      }
    }
    else {
      sd <- dendrapply(sd, addcol, col_above_h, groupLabels[groupsinsubtree])
      if (!is.null(groupLabels)) {
        attr(sd, "edgetext") <- groupLabels[groupsinsubtree]
        attr(sd, "edgePar") <- list(p.border = "gray80")
        attr(sd, "nodePar") <- list(lab.cex = 1.4, pch=NA)#, lab.col = "1")
      }
    }
    unclass(sd)
  }
  if (!is.character(labels(dend))) 
    labels(dend) <- as.character(labels(dend))
  dend <- descendTree(dend)
  class(dend) <- "dendrogram"
  
  if (labels_arent_unique) 
    labels(dend) <- old_labels
  dend
}
  