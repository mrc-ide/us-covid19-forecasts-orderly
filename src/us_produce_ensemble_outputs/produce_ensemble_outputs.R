## orderly::orderly_develop_start(use_draft = "newer", parameters = list(week_ending = "2021-01-01", location = "Alabama"))
message("############################################################")
message("LOCATION ", location)
message("week_ending ", week_ending)
message("############################################################")
probs <- c(0.01, 0.025, seq(0.05, 0.95, by = 0.05), 0.975, 0.99)

run_info <- orderly::orderly_run_info()
output_files <- run_info$depends$as

# ## Only need this during report development stage
## output_files <- list("RtI0_Std_results.rds",
##                      "sbkp_Std_results.rds",
##                      "DeCa_Std_results.rds")

model_outputs <- map(output_files, readRDS)
names(model_outputs) <- sub("\\_.*", "", output_files)


## Equal weighted models

outputs <- map(model_outputs, ~ .[["Predictions"]])

ensemble_model_predictions <- ensemble_predictions(outputs, weights = NULL)

ensemble_daily_qntls <- rincewind::extract_predictions_qntls(ensemble_model_predictions, probs)

ensemble_weekly_qntls <- rincewind::daily_to_weekly(ensemble_model_predictions)


ensemble_daily_qntls$forecast_date <- week_ending
ensemble_daily_qntls$state <- location

saveRDS(
  object = ensemble_model_predictions,
  file = "ensemble_model_predictions.rds"
)

saveRDS(
  object = ensemble_daily_qntls,
  file = "ensemble_daily_qntls.rds"
)

saveRDS(
  object = ensemble_weekly_qntls,
  file = "ensemble_weekly_qntls.rds"
)



######################################################################
########### Rt quantiles #############################################
########### Unweighted ###############################################
######################################################################
######################################################################
outputs <- map(model_outputs, ~ .[["R_last"]])

## Sample 10,000 times from the Rt values from the different models

y <- outputs
models_this_week <- names(y)

wts <- data.frame(
  model = models_this_week,
  normalised_wt = 1
)
weights <- list(si_1 = wts, si_2 = wts)

y_1 <- map(y, ~ .[[1]])
y_2 <- map(y, ~ .[[2]])
weights <- map(weights, df_to_list)

ensemble_model_rt_samples <-  list(
  si_1 = pool_rt_weighted(y_1, weights$si_1),
  si_2 = pool_rt_weighted(y_2, weights$si_2)
)


## Calculate quantiles from these rt samples

ensemble_model_rt_qntls <- imap(ensemble_model_rt_samples, function(si, label) {

  qntls <- quantile(si, probs = probs)
  qntls <- tibble::rownames_to_column(
    data.frame(out2 = qntls),
    var = "quantile"
  )
  qntls$si <- label

  qntls

}
)

ensemble_model_rt_qntls <- dplyr::bind_rows(ensemble_model_rt_qntls)
ensemble_model_rt_qntls$forecast_date <- week_ending
ensemble_model_rt_qntls$state <- location

## Save outputs

ensemble_model_rt_samples <- as.data.frame(ensemble_model_rt_samples)

saveRDS(
  object = ensemble_model_rt_samples,
  file = "ensemble_model_rt_samples.rds"
)

saveRDS(
  object = ensemble_model_rt_qntls,
  file = "ensemble_model_rt.rds"
)



######################################################################
## Previous code - not sure if still needed at some point...
##
##
## countries <- names(ensemble_model_predictions[[1]])
## walk(
##   countries,
##   function(country) {

##     unwtd <- t(ensemble_model_predictions[[1]][[country]][[2]])
##     all_prev <- t(wtd_ensb_all_prev_weeks[[1]][[country]][[2]])
##     prev_week <- t(wtd_ensb_prev_week[[1]][[country]][[2]])

##     unwtd <- data.frame(unwtd) %>%
##       tibble::rownames_to_column(var = "date") %>%
##       tidyr::gather("var", "val", -date)

##     all_prev <-  data.frame(all_prev) %>%
##       tibble::rownames_to_column(var = "date") %>%
##       tidyr::gather("var", "val", -date)

##     prev_week <- data.frame(prev_week) %>%
##       tibble::rownames_to_column(var = "date") %>%
##       tidyr::gather("var", "val", -date)

##     x <- bind_rows(
##       list(
##         unwtd = unwtd, all_prev = all_prev, prev_week = prev_week
##       ),
##       .id = "model"
##     )
##     x$date <- as.Date(x$date)

##     p <- ggplot(x) +
##       geom_density(
##         aes(x = val, color = model)
##       ) +
##       facet_wrap(~date, nrow = 7) +
##       theme_classic() +
##       theme(
##         legend.position = "top",
##         legend.title = element_blank()
##       ) + xlab("")

##     ggsave(
##       filename = glue::glue("{country}_density.png"),
##       plot = p
##     )
##   }
## )
