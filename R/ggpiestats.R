#' @title Pie charts with statistical tests
#' @name ggpiestats
#' @description Pie charts for categorical data with statistical details
#'   included in the plot as a subtitle.
#' @author Indrajeet Patil
#'
#' @param factor.levels A character vector with labels for factor levels of
#'   `main` variable.
#' @param title The text for the plot title.
#' @param caption The text for the plot caption.
#' @param sample.size.label Logical that decides whether sample size information
#'   should be displayed for each level of the grouping variable `condition`
#'   (Default: `TRUE`).
#' @param palette If a character string (e.g., `"Set1"`), will use that named
#'   palette. If a number, will index into the list of palettes of appropriate
#'   type. Default palette is `"Dark2"`.
#' @param facet.wrap.name The text for the facet_wrap variable label.
#' @param facet.proptest Decides whether proportion test for `main` variable is
#'   to be carried out for each level of `condition` (Default: `TRUE`).
#' @param perc.k Numeric that decides number of decimal places for percentage
#'   labels (Default: `0`).
#' @param slice.label Character decides what information needs to be displayed
#'   on the label in each pie slice. Possible options are `"percentage"`
#'   (default), `"counts"`, `"both"`.
#' @param label.text.size Numeric that decides text size for slice/bar labels
#'   (Default: `4`).
#' @param label.fill.color Character that specifies fill color for slice/bar
#'   labels (Default: `white`).
#' @param label.fill.alpha Numeric that specifies fill color transparency or
#'   `"alpha"` for slice/bar labels (Default: `1` range `0` to `1`).
#' @param bf.message Logical that decides whether to display a caption with
#'   results from bayes factor test in favor of the null hypothesis (default:
#'   `FALSE`).
#' @inheritParams bf_contingency_tab
#' @inheritParams subtitle_contingency_tab
#' @inheritParams subtitle_onesample_proptest
#' @inheritParams paletteer::scale_fill_paletteer_d
#' @inheritParams theme_ggstatsplot
#' @inheritParams gghistostats
#' @inheritParams cat_label_df
#'
#' @import ggplot2
#'
#' @importFrom dplyr select group_by summarize n arrange if_else desc
#' @importFrom dplyr mutate mutate_at mutate_if
#' @importFrom rlang !! enquo quo_name
#' @importFrom crayon green blue yellow red
#' @importFrom paletteer scale_fill_paletteer_d
#' @importFrom groupedstats grouped_proptest
#' @importFrom tidyr uncount
#' @importFrom tibble as_tibble
#'
#' @references
#' \url{https://indrajeetpatil.github.io/ggstatsplot/articles/web_only/ggpiestats.html}
#'
#' @return Unlike a number of statistical softwares, `ggstatsplot` doesn't
#'   provide the option for Yates' correction for the Pearson's chi-squared
#'   statistic. This is due to compelling amount of Monte-Carlo simulation
#'   research which suggests that the Yates' correction is overly conservative,
#'   even in small sample sizes. As such it is recommended that it should not
#'   ever be applied in practice (Camilli & Hopkins, 1978, 1979; Feinberg, 1980;
#'   Larntz, 1978; Thompson, 1988).
#'
#' @examples
#'
#' # for reproducibility
#' set.seed(123)
#'
#' # simple function call with the defaults (without condition)
#' ggstatsplot::ggpiestats(
#'   data = ggplot2::msleep,
#'   main = vore,
#'   perc.k = 1,
#'   k = 2
#' )
#'
#' # simple function call with the defaults (with condition)
#' ggstatsplot::ggpiestats(
#'   data = datasets::mtcars,
#'   main = vs,
#'   condition = cyl,
#'   bf.message = TRUE,
#'   nboot = 10,
#'   factor.levels = c("0 = V-shaped", "1 = straight"),
#'   legend.title = "Engine"
#' )
#'
#' # simple function call with the defaults (without condition; with count data)
#' library(jmv)
#'
#' ggstatsplot::ggpiestats(
#'   data = as.data.frame(HairEyeColor),
#'   main = Eye,
#'   counts = Freq
#' )
#' @export

# defining the function
ggpiestats <- function(data,
                       main,
                       condition = NULL,
                       counts = NULL,
                       ratio = NULL,
                       paired = FALSE,
                       results.subtitle = TRUE,
                       factor.levels = NULL,
                       stat.title = NULL,
                       sample.size.label = TRUE,
                       label.separator = "\n",
                       label.text.size = 4,
                       label.fill.color = "white",
                       label.fill.alpha = 1,
                       bf.message = FALSE,
                       sampling.plan = "indepMulti",
                       fixed.margin = "rows",
                       prior.concentration = 1,
                       title = NULL,
                       subtitle = NULL,
                       caption = NULL,
                       conf.level = 0.95,
                       nboot = 100,
                       simulate.p.value = FALSE,
                       B = 2000,
                       legend.title = NULL,
                       facet.wrap.name = NULL,
                       k = 2,
                       perc.k = 0,
                       slice.label = "percentage",
                       facet.proptest = TRUE,
                       ggtheme = ggplot2::theme_bw(),
                       ggstatsplot.layer = TRUE,
                       package = "RColorBrewer",
                       palette = "Dark2",
                       direction = 1,
                       ggplot.component = NULL,
                       messages = TRUE) {

  # ================= extracting column names as labels  =====================

  # saving the column label for the 'main' variables
  if (is.null(legend.title)) {
    legend.title <- rlang::as_name(rlang::ensym(main))
  }

  # if facetting variable name is not specified, use the variable name for
  # 'condition' argument
  if (!base::missing(condition)) {
    if (is.null(facet.wrap.name)) {
      facet.wrap.name <- rlang::as_name(rlang::ensym(condition))
    }
  }

  # =============================== dataframe ================================

  # creating a dataframe
  data <-
    dplyr::select(
      .data = data,
      main = !!rlang::enquo(main),
      condition = !!rlang::enquo(condition),
      counts = !!rlang::enquo(counts)
    ) %>%
    tidyr::drop_na(data = .) %>%
    tibble::as_tibble(x = .)

  # =========================== converting counts ============================

  # untable the dataframe based on the count for each obervation
  if (!base::missing(counts)) {
    data %<>%
      tidyr::uncount(
        data = .,
        weights = counts,
        .remove = TRUE,
        .id = "id"
      )
  }

  # ============================ percentage dataframe ========================

  # main and condition need to be a factor for this analysis
  # also drop the unused levels of the factors

  # main
  data %<>%
    dplyr::mutate(.data = ., main = droplevels(as.factor(main)))

  # condition
  if (!base::missing(condition)) {
    data %<>%
      dplyr::mutate(.data = ., condition = droplevels(as.factor(condition)))
  }

  # convert the data into percentages; group by conditional variable if needed
  df <- cat_counter(data, main, condition)

  # dataframe with summary labels
  df %<>%
    cat_label_df(
      data = .,
      label.col.name = "slice.label",
      label.content = slice.label,
      label.separator = label.separator,
      perc.k = perc.k
    )

  # ============================ sample size label ==========================

  # if sample size labels are to be displayed at the bottom of the pie charts
  # for each facet
  if (isTRUE(sample.size.label)) {
    if (!base::missing(condition)) {
      df_n_label <-
        dplyr::full_join(
          x = df,
          y = df %>%
            dplyr::group_by(.data = ., condition) %>%
            dplyr::summarize(.data = ., total_n = sum(counts)) %>%
            dplyr::ungroup(x = .) %>%
            dplyr::mutate(
              .data = .,
              condition_n_label = paste("(n = ", total_n, ")", sep = "")
            ) %>%
            # changing character variables into factors
            dplyr::mutate_if(
              .tbl = .,
              .predicate = purrr::is_bare_character,
              .funs = ~ base::as.factor(.)
            ),
          by = "condition"
        ) %>%
        dplyr::mutate(
          .data = .,
          condition_n_label = dplyr::if_else(
            condition = base::duplicated(condition),
            true = NA_character_,
            false = as.character(condition_n_label)
          )
        ) %>%
        tidyr::drop_na(data = .)
    }
  }

  # ================= preparing names for legend and facet_wrap ==============

  # reorder the category factor levels to order the legend
  df$main <- factor(x = df$main, levels = unique(df$main))

  # getting labels for all levels of the 'main' variable factor
  if (is.null(factor.levels)) {
    legend.labels <- as.character(df$main)
  } else if (!missing(factor.levels)) {
    legend.labels <- factor.levels
  }

  # custom labeller function to use if the user wants a different name for
  # facet_wrap variable
  label_facet <- function(original_var, custom_name) {
    lev <- levels(as.factor(original_var))
    lab <- paste0(custom_name, ": ", lev)
    names(lab) <- lev
    return(lab)
  }

  # =================================== plot =================================

  # if no. of factor levels is greater than the default palette color count
  palette_message(
    package = package,
    palette = palette,
    min_length = length(unique(levels(data$main)))[[1]]
  )

  # creating the basic plot
  p <- ggplot2::ggplot(
    data = df,
    mapping = ggplot2::aes(x = "", y = counts)
  ) +
    ggplot2::geom_col(
      position = "fill",
      color = "black",
      width = 1,
      ggplot2::aes(fill = factor(get("main"))),
      na.rm = TRUE
    ) +
    ggplot2::geom_label(
      ggplot2::aes(label = slice.label, group = factor(get("main"))),
      position = ggplot2::position_fill(vjust = 0.5),
      color = "black",
      size = label.text.size,
      fill = label.fill.color,
      alpha = label.fill.alpha,
      show.legend = FALSE,
      na.rm = TRUE
    )

  # if facet_wrap is *not* happening
  if (base::missing(condition)) {
    p <- p +
      ggplot2::coord_polar(theta = "y")
  } else {
    # if facet_wrap *is* happening
    p <- p +
      ggplot2::facet_wrap(
        facets = ~condition,
        labeller = ggplot2::labeller(
          condition = label_facet(
            original_var = df$condition,
            custom_name = facet.wrap.name
          )
        )
      ) +
      ggplot2::coord_polar(theta = "y")
  }

  # formatting
  p <- p +
    ggplot2::scale_y_continuous(breaks = NULL) +
    paletteer::scale_fill_paletteer_d(
      package = !!package,
      palette = !!palette,
      direction = direction,
      name = "",
      labels = unique(legend.labels)
    ) +
    theme_pie(
      ggtheme = ggtheme,
      ggstatsplot.layer = ggstatsplot.layer
    ) +
    # remove black diagonal line from legend
    ggplot2::guides(
      fill = ggplot2::guide_legend(override.aes = list(color = NA))
    )

  # =============== chi-square test (either Pearson or McNemar) =============

  # if facetting by condition is happening
  if (!base::missing(condition)) {
    if (isTRUE(facet.proptest)) {
      # merging dataframe containing results from the proportion test with
      # counts and percentage dataframe
      df2 <-
        dplyr::full_join(
          x = df,
          # running grouped proportion test with helper functions
          y = groupedstats::grouped_proptest(
            data = data,
            grouping.vars = condition,
            measure = main
          ),
          by = "condition"
        ) %>%
        dplyr::mutate(
          .data = .,
          significance = dplyr::if_else(
            condition = duplicated(condition),
            true = NA_character_,
            false = significance
          )
        ) %>%
        dplyr::filter(.data = ., !is.na(significance))

      # display grouped proportion test results
      if (isTRUE(messages)) {
        # tell the user what these results are
        proptest_message(
          main = rlang::as_name(rlang::ensym(main)),
          condition = rlang::as_name(rlang::ensym(condition))
        )

        # print the tibble and leave out unnecessary columns
        print(tibble::as_tibble(df2) %>%
          dplyr::select(.data = ., -c(main:slice.label)))
      }
    }

    # if subtitle with results is to be displayed
    if (isTRUE(results.subtitle)) {
      subtitle <-
        subtitle_contingency_tab(
          data = data,
          main = main,
          condition = condition,
          nboot = nboot,
          paired = paired,
          stat.title = stat.title,
          conf.level = conf.level,
          conf.type = "norm",
          simulate.p.value = simulate.p.value,
          B = B,
          messages = messages,
          k = k
        )

      # preparing the BF message for null hypothesis support
      if (isTRUE(bf.message)) {
        bf.caption.text <-
          bf_contingency_tab(
            data = data,
            main = main,
            condition = condition,
            sampling.plan = sampling.plan,
            fixed.margin = fixed.margin,
            prior.concentration = prior.concentration,
            caption = caption,
            output = "caption",
            k = k
          )

        # assign it to captio
        caption <- bf.caption.text
      }
    }

    # ====================== facetted proportion test =======================

    # adding significance labels to pie charts for grouped proportion tests
    if (isTRUE(facet.proptest)) {
      p <-
        p +
        ggplot2::geom_text(
          data = df2,
          mapping = ggplot2::aes(label = significance, x = 1.65),
          position = ggplot2::position_fill(vjust = 1),
          size = 5,
          na.rm = TRUE
        )
    }

    # adding sample size info
    if (isTRUE(sample.size.label)) {
      p <-
        p +
        ggplot2::geom_text(
          data = df_n_label,
          mapping = ggplot2::aes(label = condition_n_label, x = 1.65),
          position = ggplot2::position_fill(vjust = 0.5),
          size = 4,
          na.rm = TRUE
        )
    }
  } else {
    if (isTRUE(results.subtitle)) {
      subtitle <- subtitle_onesample_proptest(
        data = data,
        main = main,
        ratio = ratio,
        legend.title = legend.title,
        k = k
      )
    }
  }

  # =========================== putting all together ========================

  # preparing the plot
  p <-
    p +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      subtitle = subtitle,
      title = title,
      caption = caption
    ) +
    ggplot2::guides(fill = ggplot2::guide_legend(title = legend.title))

  # ---------------- adding ggplot component ---------------------------------

  # if any additional modification needs to be made to the plot
  # this is primarily useful for grouped_ variant of this function
  p <- p + ggplot.component

  # return the final plot
  return(p)
}
