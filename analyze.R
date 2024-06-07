rm(list = ls())
library(tidyverse)
library(glue)

pairwise_cohens_kappa <- function(df) {
    combn(names(df), 2, function(pair) {
        kappa_data <- df |> select(all_of(pair))
        kappa_result <- irr::kappa2(as.matrix(kappa_data))

        val <- round(kappa_result$value, 2)


        tibble(
            rater1 = pair[1],
            rater2 = pair[2],
            kappa = kappa_result$value,
            p.value = kappa_result$p.value,
            joint_prob = mean(kappa_data[[pair[1]]] == kappa_data[[pair[2]]]),
            label = factor(case_when(
                val < 0 ~ "Poor",
                val > 0 & val <= 0.2 ~ "Slight",
                val >= 0.21 & val <= 0.4 ~ "Fair",
                val >= 0.41 & val <= 0.6 ~ "Moderate",
                val >= 0.61 & val <= 0.8 ~ "Substantial",
                val >= 0.81 ~ "Almost perfect",
                TRUE ~ "Unknown"
            ), levels = c("None", "Slight", "Fair", "Moderate", "Substantial", "Almost perfect", "Unknown"))
        )
    }, simplify = FALSE) |> bind_rows()
}

plot_pairwise <- function(df, N) {
    subtitle <- 'Cohen\'s kappa'
    label_fill <- scales::label_number()

    format_kappa <- function(x) { round(x, 2) }
    format_pct <- function(x) { str_c(round(x * 100), "%") }


    plt <- df |>
        bind_rows(df |> rename(rater2 = rater1, rater1 = rater2)) |>
        mutate(
            rater1 = fct_relevel(rater1, "Journalist A", "Journalist B"),
            rater2 = fct_relevel(rater2, "Journalist A", "Journalist B") |> fct_rev(),
            color_choice = if_else(kappa < 0.2 | kappa > 0.8, "low", "high")
        ) |>
        ggplot(aes(x = rater1, y = rater2)) +
        geom_tile(aes(fill = kappa)) +
        geom_text(aes(label = format_kappa(kappa), color = color_choice), size = 11) +
        geom_text(aes(label = str_c(format_pct(joint_prob), " | ", label), color = color_choice), vjust = 4) +
        scale_fill_steps2(
            mid = "#f7f7f7", low = "#990000", high = "#009900",
            midpoint = 0.5,
            labels = label_fill,
            limits = c(0, 1), breaks = seq(0, 1, by = 0.1)) +
        scale_color_manual(values = c(low = 'white', high = 'black')) +
        scale_x_discrete(position = "top") +
        guides(
            color = 'none',
        ) +
        theme(legend.key.width = unit(2, "cm"), legend.position = "top") +
        labs(title = "Inter-rater agreement", fill = "", subtitle = subtitle, caption = "N = {N}" |> glue())

    plt
}


dat <- read_csv("./data/classification.csv")
dat_wide <- dat |> pivot_wider(id_cols = c(id, title), names_from = rater, values_from = perspective)
pairwise <- dat_wide |> select(-c(id, title)) |> pairwise_cohens_kappa()

pairwise |> plot_pairwise(N = nrow(dat_wide))
pairwise |> plot_pairwise(N = nrow(dat_wide))


dat |>
    group_by(rater, perspective) |>
    summarize(n = n()) |>
    group_by(rater) |>
    mutate(prop = n / sum(n)) |>
    ungroup() |>
    ggplot(aes(x = perspective, y = prop, fill = rater)) +
    geom_col() +
    facet_wrap(~rater)
