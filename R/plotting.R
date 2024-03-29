#' @importFrom tidygraph tbl_graph activate
#' @importFrom ggplot2 ggsave labs aes coord_equal scale_colour_manual scale_size_manual facet_wrap geom_line geom_text ggplot theme_bw geom_path geom_point geom_step aes_string scale_linetype_manual
#' @importFrom ggraph circle geom_edge_fan geom_edge_loop geom_node_circle geom_node_text ggraph scale_edge_width_continuous theme_graph geom_node_label geom_node_point
#' @importFrom viridis scale_color_viridis
#' @importFrom grid arrow unit
NULL

effect_colour <- function(effect) {
  index <- match(effect, c(1, -1, -2, NA, 0))
  c(
    "#3793d6",     # activating => blue
    "#d63737",     # repressing => red
    "#00000000",   # not real => invisible
    "darkgray",    # not decided yet
    "#7cd637"      # ??? :P => green
  )[index]
}

#' Visualise the backbone state network of a model
#' 
#' @param model A dyngen initial model created with [initialise_model()].
#' @param detailed Whether or not to also plot the substates of transitions.
#' 
#' @return A ggplot2 object.
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("example_model")
#' plot_backbone_statenet(example_model)
#' }
plot_backbone_statenet <- function(model, detailed = FALSE) {
  edges <- model$backbone$expression_patterns
  
  large_cap <- 4
  small_cap <- 1
  if (detailed) {
    edges <- .generate_gold_standard_mod_changes(edges) %>% 
      rename(
        from = .data$from_, 
        to = .data$to_, 
        from_ = .data$from, 
        to_ = .data$to, 
        module_progression = .data$mod_diff
      ) %>% 
      mutate(
        from_cap = ifelse(.data$from == .data$from_, large_cap, small_cap),
        to_cap = ifelse(.data$to == .data$to_, large_cap, small_cap)
      )
    nodes <- tibble(
      name = unique(c(edges$from, edges$to)),
      main = .data$name %in% c(edges$from_, edges$to_)
    )
  } else {
    nodes <- tibble(
      name = unique(c(edges$from, edges$to)),
      main = TRUE
    )
    edges <- edges %>% mutate(
      from_cap = large_cap,
      to_cap = large_cap
    )
  }
  
  gr <- tbl_graph(edges = edges %>% rename(weight = .data$time), nodes = nodes)
  
  r <- .05
  arrow <- grid::arrow(type = "closed", length = grid::unit(3, "mm"))
  
  ggraph(gr, layout = "igraph", algorithm = "kk") +
    geom_edge_fan_workaround(edges, 
      aes(
        label = .data$module_progression,
        start_cap = circle(.data$from_cap, "mm"),
        end_cap = circle(.data$to_cap, "mm")
      ), 
      arrow = arrow, 
      colour = "gray"
    ) +
    geom_node_point(data = function(df) df %>% filter(!.data$main)) +
    geom_node_label(aes(label = .data$name), function(df) df %>% filter(.data$main)) +
    theme_graph(base_family = 'Helvetica') +
    coord_equal()
}

#' Visualise the backbone of a model
#' 
#' @param model A dyngen initial model created with [initialise_model()].
#' 
#' @return A ggplot2 object.
#' 
#' @importFrom igraph layout.graphopt V E
#' @export
#' 
#' @examples
#' \donttest{
#' data("example_model")
#' plot_backbone_modulenet(example_model)
#' }
plot_backbone_modulenet <- function(model) {
  # satisfy r cmd check
  module_id <- color <- from <- to <- strength <- effect <- name <- NULL
  
  node_legend <- model$backbone$module_info %>% select(module_id, color) %>% deframe()
  
  nodes <- model$backbone$module_info %>% rename(name = module_id)
  edges <- model$backbone$module_network %>% arrange(from == to)
  
  gr <- tbl_graph(nodes = nodes, edges = edges)
  layout <- 
    gr %>% 
    igraph::layout.graphopt(charge = .01, niter = 10000) %>% 
    dynutils::scale_minmax() %>% 
    as.data.frame() 
  rownames(layout) <- nodes$name
  colnames(layout) <- c("x", "y")
  
  r <- .03
  cap <- circle(4, "mm")
  str <- .2
  arrow_up <- grid::arrow(type = "closed", angle = 30, length = grid::unit(3, "mm"))
  arrow_down <- grid::arrow(type = "closed", angle = 89, length = grid::unit(3, "mm"))
  
  ggraph(gr, layout = "manual", x = layout$x, y = layout$y) +
    geom_edge_loop_workaround(edges, aes(width = strength, strength = str, filter = effect >= 0 & from == to), arrow = arrow_up, start_cap = cap, end_cap = cap) +
    geom_edge_loop_workaround(edges, aes(width = strength, strength = str, filter = effect < 0 & from == to), arrow = arrow_down, start_cap = cap, end_cap = cap) +
    geom_edge_fan_workaround(edges, aes(width = strength, filter = effect >= 0 & from != to), arrow = arrow_up, start_cap = cap, end_cap = cap) +
    geom_edge_fan_workaround(edges, aes(width = strength, filter = effect < 0 & from != to), arrow = arrow_down, start_cap = cap, end_cap = cap) +
    geom_node_circle(aes(r = r, colour = name), fill = "white") +
    geom_node_text(aes(label = name)) +
    theme_graph(base_family = 'Helvetica') +
    scale_colour_manual(values = node_legend) +
    scale_edge_width_continuous(trans = "log10", range = c(.5, 3)) +
    coord_equal()
}

#' Visualise the feature network of a model
#' 
#' @param model A dyngen intermediary model for which the feature network has been generated with [generate_feature_network()].
#' @param show_tfs Whether or not to show the transcription factors.
#' @param show_targets Whether or not to show the targets.
#' @param show_hks Whether or not to show the housekeeping genes.
#' 
#' @return A ggplot2 object.
#' 
#' @importFrom igraph layout_with_fr V E
#' @export
#' 
#' @examples
#' \donttest{
#' data("example_model")
#' plot_feature_network(example_model)
#' }
plot_feature_network <- function(
  model,
  show_tfs = TRUE,
  show_targets = TRUE,
  show_hks = FALSE
) {
  # satisfy r cmd check
  module_id <- color <- is_tf <- is_hk <- color_by <- from <- to <- 
    feature_id <- `.` <- edges <- effect <- NULL
  
  # get feature info
  feature_info <- 
    model$feature_info %>%
    mutate(
      color_by = case_when(
        !is.na(module_id) ~ module_id,
        is_tf ~ "TF",
        !is_hk ~ "Target",
        is_hk ~ "HK"
      )
    )
  
  color_legend <- c(
    "TF" = "black",
    "Target" = "darkgray",
    "HK" = "lightgray",
    model$backbone$module_info %>% select(module_id, color) %>% deframe()
  )
  
  # remove unwanted features and convert NA into "NA"
  feature_info <- 
    feature_info %>% 
    filter(
      show_tfs & is_tf |
      show_targets & !is_tf & !is_hk |
      show_hks & is_hk
    ) %>% 
    mutate(
      color_by = ifelse(is.na(color_by), "NA", color_by)
    )
  
  # filter feature network
  feature_network <- 
    model$feature_network %>% 
    filter(from %in% feature_info$feature_id & to %in% feature_info$feature_id) %>% 
    arrange(from == to)
  
  # add extra edges invisible between regulators from the same module
  feature_network <-
    bind_rows(
      feature_network,
      feature_info %>%
        filter(is_tf) %>%
        select(module_id, feature_id) %>%
        group_by(module_id) %>%
        do({
          crossing(from = .$feature_id, to = .$feature_id) %>%
            mutate(effect = -2)
        }) %>%
        ungroup() %>%
        filter(from < to)
    )
  
  gr <- tbl_graph(nodes = feature_info, edges = feature_network)
  layout <- igraph::layout_with_fr(gr) %>% 
    dynutils::scale_minmax() %>%
    as.data.frame()
  rownames(layout) <- feature_info$feature_id
  colnames(layout) <- c("x", "y")
  
  gr <- gr %>% activate(edges) %>% filter(is.na(effect) | effect != -2)
  
  cap <- circle(2.5, "mm")
  str <- .2
  
  arrow_up <- grid::arrow(type = "closed", angle = 30, length = grid::unit(3, "mm"))
  arrow_down <- grid::arrow(type = "closed", angle = 89, length = grid::unit(3, "mm"))
  
  ggraph(gr, layout = "manual", x = layout$x, y = layout$y) +
    geom_edge_loop_workaround(feature_network, aes(strength = str, filter = !is.na(effect) & effect >= 0 & from == to), arrow = arrow_up, start_cap = cap, end_cap = cap) +
    geom_edge_loop_workaround(feature_network, aes(strength = str, filter = !is.na(effect) & effect < 0 & from == to), arrow = arrow_down, start_cap = cap, end_cap = cap) +
    geom_edge_loop_workaround(feature_network, aes(strength = str, filter = is.na(effect) & from == to)) +
    geom_edge_fan_workaround(feature_network, aes(filter = !is.na(effect) & effect >= 0 & from != to), arrow = arrow_up, start_cap = cap, end_cap = cap) +
    geom_edge_fan_workaround(feature_network, aes(filter = !is.na(effect) & effect < 0 & from != to), arrow = arrow_down, start_cap = cap, end_cap = cap) +
    geom_edge_fan_workaround(feature_network, aes(filter = is.na(effect) & from != to)) +
    geom_node_point(aes(colour = color_by, size = as.character(is_tf))) +
    theme_graph(base_family = "Helvetica") +
    scale_colour_manual(values = color_legend) +
    scale_size_manual(values = c("TRUE" = 5, "FALSE" = 3)) +
    coord_equal() +
    labs(size = "is TF", color = "Module group")
}

#' Visualise the simulations using the dimred
#' 
#' @param model A dyngen intermediary model for which the simulations have been run with [generate_cells()].
#' @param mapping Which components to plot.
#' 
#' @return A ggplot2 object.
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("example_model")
#' plot_simulations(example_model)
#' }
plot_simulations <- function(model, mapping = aes_string("comp_1", "comp_2")) {
  plot_df <- 
    bind_cols(
      model$simulations$meta,
      model$simulations$dimred %>% as.data.frame
    )
  
  ggplot(plot_df %>% filter(.data$sim_time >= 0), mapping) +
    geom_path(aes(colour = .data$sim_time, group = .data$simulation_i)) +
    viridis::scale_color_viridis() +
    theme_bw()
}

#' Visualise the simulations using the dimred
#' 
#' @param model A dyngen intermediary model for which the simulations have been run with [generate_cells()].
#' @param detailed Whether or not to colour according to each separate sub-edge in the gold standard.
#' @param mapping Which components to plot.
#' @param highlight Which simulation to highlight. If highlight == 0 then the gold simulation will be highlighted.
#' 
#' @return A ggplot2 object.
#' 
#' @export
#' 
#' @examples
#' data("example_model")
#' plot_gold_simulations(example_model)
plot_gold_simulations <- function(model, detailed = FALSE, mapping = aes_string("comp_1", "comp_2"), highlight = 0) {
  plot_df <- 
    bind_cols(
      model$gold_standard$meta,
      model$gold_standard$dimred %>% as.data.frame
    ) %>% filter(!.data$burn)
  
  if (!detailed && model %has_names% "simulations" && model$simulations %has_names% "dimred") {
    plot_df <- plot_df %>% 
      bind_rows(
        bind_cols(
          model$simulations$meta,
          model$simulations$dimred %>% as.data.frame
        ) %>% filter(.data$sim_time >= 0)
      )
  }
  
  plot_df <- plot_df %>% mutate(group = paste0(.data$from_, "->", .data$to_))
  
  if (detailed) {
    plot_df <- plot_df %>% mutate(edge = .data$group)
  } else {
    plot_df <- plot_df %>% mutate(edge = paste0(.data$from, "->", .data$to))
  }
  
  ggplot(mapping = mapping) +
    geom_path(aes(group = .data$simulation_i), plot_df %>% filter(.data$simulation_i != highlight), colour = "darkgray") +
    geom_path(aes(colour = .data$edge, group = .data$group), plot_df %>% filter(.data$simulation_i == highlight), size = 2) +
    theme_bw() +
    labs(colour = "Edge")
}

#' Visualise the mapping of the simulations to the gold standard
#' 
#' @param model A dyngen intermediary model for which the simulations have been run with [generate_cells()].
#' @param selected_simulations Which simulation indices to visualise.
#' @param do_facet Whether or not to facet according to simulation index.
#' @param mapping Which components to plot.
#' 
#' @return A ggplot2 object.
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("example_model")
#' plot_gold_mappings(example_model)
#' }
plot_gold_mappings <- function(model, selected_simulations = NULL, do_facet = TRUE, mapping = aes_string("comp_1", "comp_2")) {
  plot_df <- 
    bind_rows(
      bind_cols(
        model$simulations$meta,
        model$simulations$dimred %>% as.data.frame
      ) %>% filter(.data$sim_time >= 0),
      bind_cols(
        model$gold_standard$meta,
        model$gold_standard$dimred %>% as.data.frame
      ) %>% filter(!.data$burn)
    )
  
  if (!is.null(selected_simulations)) {
    plot_df <- plot_df %>% filter(.data$simulation_i %in% selected_simulations)
  }
  
  plot_df <- plot_df %>% mutate(edge = paste0(.data$from, "->", .data$to))
  
  g <- ggplot(mapping = mapping) +
    geom_path(aes(colour = .data$edge, linetype = "Gold standard"), plot_df %>% filter(.data$simulation_i == 0)) +
    geom_path(aes(colour = .data$edge, group = .data$simulation_i, linetype = "Simulation"), plot_df %>% filter(.data$simulation_i != 0)) +
    theme_bw() +
    scale_linetype_manual(values = c("Gold standard" = "dotted", "Simulation" = "solid")) + 
    labs(linetype = "Sim. type", colour = "Edge")
  
  if (do_facet) {
    g <- g +
    facet_wrap(~ simulation_i)
  }
  
  g
}


#' Visualise the expression of the gold standard over simulation time
#' 
#' @param model A dyngen intermediary model for which the simulations have been run with [generate_gold_standard()].
#' @param what Which molecule types to visualise.
#' @param label_changing Whether or not to add a label next to changing molecules.
#' 
#' @return A ggplot2 object.
#' 
#' @export
#' 
#' @examples
#' data("example_model")
#' plot_gold_expression(example_model, what = "mol_mrna", label_changing = FALSE)
plot_gold_expression <- function(
  model, 
  what = c("mol_premrna", "mol_mrna", "mol_protein"),
  label_changing = TRUE
) {
  # satisfy r cmd check
  from_ <- to_ <- edge <- is_tf <- mol <- val <- molecule <- value <- module_id <- 
    type <- sim_time <- simulation_i <- burn <- from <- to <- time <- color <- NULL
  
  assert_that(what %all_in% c("mol_premrna", "mol_mrna", "mol_protein"))
  
  edge_levels <- 
    model$gold_standard$mod_changes %>% 
    mutate(edge = paste0(from_, "->", to_)) %>% 
    pull(edge)
  
  molecules <- model$feature_info %>% filter(is_tf) %>% gather(mol, val, !!!what) %>% pull(val)
  df <- bind_cols(
    model$gold_standard$meta,
    as.data.frame(as.matrix(model$gold_standard$counts))[,molecules]
  ) %>% 
    gather(molecule, value, one_of(molecules)) %>% 
    mutate(edge = factor(paste0(from_, "->", to_), levels = edge_levels)) %>% 
    left_join(model$feature_info %>% select(module_id, !!!what) %>% gather(type, molecule, !!!what), by = "molecule") %>% 
    group_by(module_id, sim_time, simulation_i, burn, from, to, from_, to_, time, edge, type) %>% 
    summarise(value = mean(value)) %>% 
    ungroup() %>% 
    filter(type %in% what)
  
  g <- ggplot(df, aes(sim_time, value, colour = module_id)) +
    geom_line(aes(linetype = type, size = type)) +
    scale_size_manual(values = c(mol_premrna = .5, mol_mrna = 1, mol_protein = .5)) +
    scale_colour_manual(values = model$backbone$module_info %>% select(module_id, color) %>% deframe) +
    facet_wrap(~edge) +
    theme_bw() +
    labs(colour = "Module id", linetype = "Molecule type")
  
  if (label_changing) {
    g <- g +
      geom_text(
        aes(label = paste0(module_id, "_", type)), 
        df %>% group_by(edge, module_id, type) %>% filter(sim_time == max(sim_time) & any(diff(value) > 0.01)) %>% ungroup,
        hjust = 1, 
        vjust = 0,
        nudge_y = .15
      )
  }
  
  g
}


#' Visualise the expression of the simulations over simulation time
#' 
#' @param model A dyngen intermediary model for which the simulations have been run with [generate_cells()].
#' @param simulation_i Which simulation to visualise.
#' @param what Which molecule types to visualise.
#' @param facet What to facet on.
#' @param label_nonzero Plot labels for non-zero molecules.
#' 
#' @return A ggplot2 object.
#' 
#' @importFrom ggrepel geom_text_repel
#' @importFrom stats approx
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("example_model")
#' plot_simulation_expression(example_model)
#' }
plot_simulation_expression <- function(
  model, 
  simulation_i = 1:4,
  what = c("mol_premrna", "mol_mrna", "mol_protein"),
  facet = c("simulation", "module_group", "module_id", "none"),
  label_nonzero = FALSE
) {
  # satisfy r check
  is_tf <- mol <- val <- molecule <- value <- module_id <- type <- sim_time <- 
    color <- module_group <- x <- y <- `.` <- NULL
  
  assert_that(what %all_in% c("mol_premrna", "mol_mrna", "mol_protein"))
  facet <- match.arg(facet)
  
  molecules <- model$feature_info %>% filter(is_tf) %>% gather(mol, val, !!!what) %>% pull(val)
  df <- bind_cols(
    model$simulations$meta,
    as.data.frame(as.matrix(model$simulations$counts)[,molecules])
  ) %>% 
    filter(simulation_i %in% !!simulation_i) %>% 
    gather(molecule, value, one_of(molecules)) %>% 
    left_join(
      model$feature_info %>%
        select(!!!what, module_id) %>% 
        gather(type, molecule, !!!what) %>% 
        mutate(type = factor(type, levels = what)), 
      by = "molecule"
    ) %>% 
    group_by(module_id, sim_time, simulation_i, type) %>% 
    summarise(value = mean(value)) %>% 
    ungroup() %>% 
    mutate(module_group = gsub("[0-9]*$", "", module_id)) %>% 
    filter(type %in% what)
  
  g <- ggplot(df, aes(sim_time, value)) +
    geom_step(aes(linetype = type, size = type, colour = module_id)) +
    scale_size_manual(values = c(mol_premrna = .5, mol_mrna = 1, mol_protein = .5)) +
    scale_colour_manual(values = model$backbone$module_info %>% select(module_id, color) %>% deframe) +
    theme_bw() +
    labs(colour = "Module id", linetype = "Molecule type")
  
  if (label_nonzero) {
    pts <- seq(0, max(model$simulations$meta$sim_time), by = 5)
    df_labels <- 
      df %>% 
      group_by(module_id, type, module_group) %>% do({
        df2 <- .
        approx(x = df2$sim_time, y = df2$value, xout = pts) %>%
          as_tibble() %>% 
          rename(sim_time = x, value = y)
      }) %>% 
      ungroup() %>% 
      filter(value > 0)
    g <- g +
      geom_point(data = df_labels) +
      ggrepel::geom_text_repel(
        aes(label = paste0(module_id, "_", type)), 
        df_labels
      )
  }
  
  if (facet == "simulation") {
    g <- g + facet_wrap(~simulation_i, ncol = 1)
  } else if (facet == "module_group") {
    g <- g + facet_wrap(~module_group, ncol = 1)
  } else if (facet == "module_id") {
    g <- g + facet_wrap(~module_id, ncol = 1)
  }
  
  g
}

#' Plot a dimensionality reduction of the final dataset
#' 
#' @param model A dyngen intermediary model for which the simulations have been run with [generate_experiment()].
#' @param mapping Which components to plot.
#' 
#' @return A ggplot2 object.
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("example_model")
#' plot_experiment_dimred(example_model)
#' }
plot_experiment_dimred <- function(model, mapping = aes_string("comp_1", "comp_2")) {
  # construct data object
  counts <- model$experiment$counts_mrna + model$experiment$counts_premrna
  dimred <- lmds::lmds(counts, distance_method = model$distance_metric)
  
  progressions <-
    model$simulations$meta[model$experiment$cell_info$step_ix, ] %>%
    mutate(
      milestone_id = ifelse(.data$time < .5, .data$from, .data$to),
      edge = paste0(.data$from, "->", .data$to)
    )
  
  plot_df <- bind_cols(progressions, as.data.frame(dimred))
  
  # create plot
  ggplot(plot_df, mapping) +
    geom_point(aes(colour = .data$edge)) +
    theme_bw() +
    labs(colour = "Edge")
}

#' @importFrom ggplot2 geom_bar scale_fill_brewer theme_classic coord_flip theme
plot_timings <- function(model) {
  timings <- 
    get_timings(model) %>% 
    mutate(
      name = paste0(.data$group, ": ", .data$task),
      name = factor(.data$name, levels = rev(.data$name))
    )
  ggplot(timings) + 
    geom_bar(aes(x = .data$name, y = .data$time_elapsed, fill = .data$group), stat = "identity") +
    scale_fill_brewer(palette = "Dark2") + 
    theme_classic() +
    theme(legend.position = "none") +
    coord_flip() + 
    labs(x = NULL, y = "Time (s)", fill = "dyngen stage")
}

#' Plot a summary of all dyngen simulation steps.
#' 
#' @param model A dyngen intermediary model for which the simulations have been run with [generate_experiment()].
#' 
#' @return A ggplot2 object.
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("example_model")
#' plot_summary(example_model)
#' }
plot_summary <- function(model) {
  # make plots :scream:
  g1 <- plot_backbone_statenet(model) + labs(title = "Backbone state network")
  g2 <- plot_backbone_modulenet(model) + labs(title = "Backbone module reg. net.")
  g3 <- plot_feature_network(model) + labs(title = "TF + target reg. net.")
  g4 <- plot_gold_simulations(model) + labs(title = "Gold + simulations")
  g5 <- plot_gold_mappings(model, do_facet = FALSE) + labs(title = "Simulations to gold mapping")
  g6 <- plot_simulations(model) + labs(title = "Simulation time")
  g7 <- plot_gold_expression(model, what = "mol_mrna") + labs(title = "Gold mRNA expression over time")
  g8 <- plot_simulation_expression(model, what = "mol_mrna") + labs(title = "Simulations 1-3 mRNA expression over time")
  g9 <- plot_experiment_dimred(model) + labs(title = "Dim. Red. of final dataset")
  
  patchwork::wrap_plots(
    g1, g2, g3, 
    g4, g5, g6,
    g7, g8, g9,
    byrow = TRUE,
    ncol = 3,
    widths = rep(1, 3),
    heights = rep(1, 3)
  ) +
    patchwork::plot_annotation(tag_levels = "A") +
    patchwork::plot_layout(guides = "collect")
}