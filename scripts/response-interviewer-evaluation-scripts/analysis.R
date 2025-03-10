library(dplyr)
library(ggplot2)
library(readr)
library(janitor)
library(tidyr)


rate_scale_long <- read.csv("./evaluation/quality-coding-annotators/rate_scale_long.csv")
rate_scale_long <- clean_names(rate_scale_long)
rate_scale_wide <- read.csv("./evaluation/quality-coding-annotators/rate_scale_wide.csv")
rate_scale_wide <- clean_names(rate_scale_wide)

binary_scale <- c("guidance", "judgement", "tone", "active_listening", "follow_up", "natural", "begin", "finish")
continuous_scale <- c("clarity", "clarity_confidence", "empathy", "empathy_confidence", "engagement", "engagement_confidence", "grammaticality", "grammaticality_confidence", "relevance", "relevance_confidence", "response_complexity", "response_complexity_confidence", "specificity", "specificity_confidence", "tone_answers", "tone_answers_confidence")   


binary_data <- rate_scale_long %>%
  filter(scale %in% binary_scale)

violations_data <- binary_data %>%
  filter(score == 1)

total_violations <- violations_data %>%
  group_by(scale) %>%
  summarize(total_count = n())

violations_relative <- violations_data %>%
  group_by(type_rater1, scale) %>%
  summarize(count = n()) %>%
  ungroup() %>%
  group_by(type_rater1) %>%
  mutate(percentage = count / sum(count) * 100)

## Violations per Interview ----
violations_summary <- violations_data %>%
  group_by(interview_identifier, type_rater1, rater) %>%
  summarize(violations = n(), .groups = 'drop')

# Calculate the average number of violations per interview between the two raters
average_violations <- violations_summary %>%
  group_by(interview_identifier, type_rater1) %>%
  summarize(avg_violations = mean(violations), .groups = 'drop')

# Separate AI and human interview types
ai_violations <- average_violations %>%
  filter(type_rater1 == "AI")


print("Violations per AI Interview")
sum(ai_violations$avg_violations / length(unique(ai_violations$interview_identifier)))

human_violations <- average_violations %>%
  filter(type_rater1 == "Human")

print("Violations per Human Interview")
sum(human_violations$avg_violations / length(unique(human_violations$interview_identifier)))


violations_relative <- violations_data %>%
  group_by(type_rater1, scale) %>%
  summarize(count = n()) %>%
  ungroup() %>%
  group_by(type_rater1) %>%
  mutate(percentage = count / sum(count) * 100)

violations_relative_plot <- ggplot(violations_relative, aes(x = scale, y = percentage, fill = type_rater1)) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_brewer(labels = c("AI", "Human"), palette = "Dark2") +
  theme_minimal() +
  geom_text(aes(label = round(percentage,2)), position = position_dodge(width = 0.9), vjust = -0.25, size = 5) +
  labs(title = "Relative Percentage of Violations by Scale and Interview Type",
       x = "Scale",
       y = "Percentage",
       fill = "Interview Type")+
  scale_x_discrete(labels = c("active_listening" = "Active Listening", 
                              "follow_up" = "Follow Up", 
                              "guidance" = "Guidance", 
                              "judgement" = "Judgement", 
                              "natural" = "Natural"))+
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 15),
    axis.text.y = element_text(size = 15),
    axis.title.x = element_text(size = 14, face = "bold", margin = margin(t = 10)),
    axis.title.y = element_text(size = 14, face = "bold", margin = margin(r = 10)),
    legend.text = element_text(size = 14),
    legend.title = element_text(size = 15, face = "bold"),
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5)
  )


ggsave("plots/violations_relative_plot.png", plot = violations_relative_plot, width = 10, height = 7.5, dpi = 300, bg = "white")


# Rating Items (1-5) ---- 

# Mean plots for ratings

summary_data <- rate_scale_wide %>%
  select(-ends_with("_confidence")) %>%
  group_by(type) %>%
  summarise(across(starts_with("grammaticality"):starts_with("tone_answers"), mean, na.rm = TRUE)) %>% 
  pivot_longer(cols = -type, names_to = "category", values_to = "average_score")


summary_data_sd <- rate_scale_wide %>%
  select(-ends_with("_confidence")) %>%
  group_by(type) %>%
  summarise(across(starts_with("grammaticality"):starts_with("tone_answers"), sd, na.rm = TRUE)) %>% 
  pivot_longer(cols = -type, names_to = "category", values_to = "sd_score")

summary_data <- cbind(summary_data, summary_data_sd$sd_score)


jitter_data <- rate_scale_wide %>%
  select(-ends_with("_confidence")) %>%
  select(type, starts_with("grammaticality"):starts_with("tone_answers")) %>% 
  group_by(type) %>%
  pivot_longer(cols = -type, names_to = "category", values_to = "average_score")



average_human_ai_across_categories <- ggplot() +
  geom_jitter(data = jitter_data, aes(x = category, y = average_score, color = as.factor(type)), height = 0, alpha = 0.05, show.legend = FALSE) +
  geom_point(data = summary_data, aes(x = category, y = average_score, color = as.factor(type)), 
             position = position_dodge(width = 0.75), size = 4, alpha = 0.6) +
  geom_errorbar(data = summary_data, aes(x = category, ymin = average_score - summary_data_sd$sd_score, ymax = average_score + summary_data_sd$sd_score, color = as.factor(type)), 
                position = position_dodge(width = 0.75), width = 0.2) +
  scale_fill_brewer(labels = c("AI" = "AI Interviewer", "Human" = "Human Interviewer"), palette = "Dark2") +
  scale_color_brewer(labels = c("AI" = "AI Interviewer", "Human" = "Human Interviewer"), palette = "Dark2") +
  labs(title = "Responses by Interview Type",
       x = "Question",
       y = "Response",
       color = "Interview type") +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 15),
    axis.text.y = element_text(size = 15),
    axis.title.x = element_text(size = 14, face = "bold", margin = margin(t = 10)),
    axis.title.y = element_text(size = 14, face = "bold", margin = margin(r = 10)),
    legend.text = element_text(size = 15),
    legend.title = element_text(size = 14, face = "bold"),
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5)
  ) +
  scale_x_discrete(labels = c("clarity" = "Clarity",
                              "grammaticality" = "Grammatical Correctness",
                              "relevance" = "Relevance",
                              "specificity" = "Specificity",
                              "empathy" = "Empathy",
                              "engagement" = "Engagement",
                              "response_complexity" = "Complexity",
                              "tone_answers" = "Tone of Answers")) +
  scale_y_continuous(breaks = 1:5) 



ggsave("plots/average_human_ai_across_categories.png", 
       average_human_ai_across_categories, 
       width = 16, 
       height = 9, 
       dpi = 300,
       bg = "white")



# Survey Response_plots -----
library(pacman)
pacman::p_load(tidyverse, rio)

# Daten einlesen: wurde zuvor in UTF-8 Zeichenkodierung umgewandelt weil R nicht mit UTF-16 klarkommt
data <- import("./evaluation/post-interview-surveys/responses_ai-interview_outcome.csv")
data <- data[2:nrow(data),] |>
  filter(!B001 == "") #herausnehmen von Zeilen, die die Fragen nicht beantwortet haben

values <- import("./evaluation/post-interview-surveys/responses_ai-interview_outcome.csv")


# Define question labels and limits
question_labels_list <- list(
  "How interesting did you find the interview process?" = c("1" = "Not interesting at all", "2" = "Slightly interesting", "3" = "Moderately interesting", "4" = "Very interesting", "5" = "Extremely interesting"),
  "How clear or unclear was it to you what the interviewer wanted from you?" = c("1" = "Everything clear", "2" = "Mostly clear", "3" = "Mostly unclear", "4" = "Everything unclear"),
  "If given the chance, would you repeat this interview?" = c("1" = "Definitely not", "2" = "Probably not", "3" = "neutral", "4" = "Probably yes", "5" = "Definitely yes"),
  "Overall, how satisfied are you with the interview?" = c("1" = "Very dissatisfied", "2" = "Dissatisfied", "3" = "neutral", "4" = "Satisfied", "5" = "Very satisfied"),
  "How well did the interviewer understand your responses?" = c("1" = "Very poorly", "2" = "Poorly", "3" = "neutral", "4" = "Well", "5" = "Very well")
)

limits_list <- list(
  c("1", "2", "3", "4", "5"),
  c("1", "2", "3", "4"),
  c("1", "2", "3", "4", "5"),
  c("1", "2", "3", "4", "5"),
  c("1", "2", "3", "4", "5")
)

fill_labels <- c("1" = "AI Interviewer", "2" = "Human Interviewer")



# Rename questions for better readability
question_labels <- c(
  "B001" = "Interestingness",
  "B002" = "Clarity",
  "B003" = "Repeatability",
  "B004" = "Satisfaction",
  "B005" = "Understanding"
)

summary_data <- data %>%
  pivot_longer(cols = starts_with("B00"), names_to = "question", values_to = "response") %>%
  mutate(response = as.numeric(response)) %>%
  group_by(C001, question) %>%
  summarize(mean_response = mean(response, na.rm = TRUE),
            sd_response = sd(response, na.rm = TRUE)) %>%
  mutate(question= recode(question, !!!question_labels)) %>% 
  ungroup()



jitter_data <- data %>%
  pivot_longer(cols = starts_with("B00"), names_to = "question", values_to = "response") %>%
  mutate(response = as.numeric(response)) %>% 
  group_by(C001, question) %>%
  rename("br_number" = "A001_01") %>% 
  select(br_number, question, response) %>% 
  mutate(question= recode(question, !!!question_labels)) %>% 
  ungroup() 





mean_plot <- ggplot() +
  geom_dotplot(data = jitter_data, aes(x = question, y = response, fill = C001), 
               binaxis = "y", stackdir = "center", position = position_dodge(width = 0.75), dotsize = 0.5, binwidth = 0.1, alpha = 0.5, show.legend = FALSE) +
  geom_point(data = summary_data, aes(x = question, y = mean_response, color = as.factor(C001)), 
             position = position_dodge(width = 0.75), size = 4, alpha = 0.6) +
  geom_errorbar(data = summary_data, aes(x = question, ymin = mean_response - sd_response, ymax = mean_response + sd_response, color = as.factor(C001)), 
                position = position_dodge(width = 0.75), width = 0.2) +
  scale_fill_brewer(labels = c("1" = "AI Interviewer", "2" = "Human Interviewer"), palette = "Dark2") +
  scale_color_brewer(labels = c("1" = "AI Interviewer", "2" = "Human Interviewer"), palette = "Dark2") +
  labs(title = "Responses by Interview Type",
       x = "Question",
       y = "Response",
       color = "Interview type") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 15),
    axis.text.y = element_text(size = 15),
    axis.title.x = element_text(size = 14, face = "bold", margin = margin(t = 10)),
    axis.title.y = element_text(size = 14, face = "bold", margin = margin(r = 10)),
    legend.text = element_text(size = 15),
    legend.title = element_text(size = 15, face = "bold"),
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5)
  )


# Save the plot
ggsave("plots/mean_responses_plot.png", plot = mean_plot,
       width = 16, 
       height = 9, 
       dpi = 300,
       bg = "white")

# Display the plot
print(mean_plot)


