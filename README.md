# **AV Gaming Behavioral Data Analysis**

## **Executive Summary**

This project explores real-world behavioral data collected from children participating in an investigation comparing active video game play and physical activity, and screen-based activities in sedentary children. The dataset provided combines multiple Excel sources (demographics, questionnaires, actigraph accelerometer data, and daily recalls)
Using Microsoft SQL Server, the project focused on data cleaning, modeling, and transformation, resolving duplicates, enforcing relationships, and creating analytical views that reveal patterns in behavior, activity, and screen time. This analysis prepares the foundation for later visualization in Power BI.

Dataset can be found here: https://catalog.data.gov/dataset/data-from-the-influence-of-active-video-game-play-upon-physical-activity-and-screen-based--33694

## **Business Problem**

The study analyzed in this project aimed to understand how active video game play influences children's physical activity and habits around the use of screens. Despite the complexity of the fragmented data across files, the key questions for this analysis are the following:

- Do children who play active video games spend less time in sedentary screen activities?
- How does overall activity (measured by actigraph data) change across weeks of the intervention?
- Can behavioral and motivational questionnaire data explain differences in activity patterns?

To answer these questions, the dataset required significant restructuring and cleaning to ensure accuracy, integrity, and usability for analytical reporting.

## **Methodology**

1. Data Integration
   - Imported the nine different Excel workbooks into SQL Server (an AV schema in SQL file).
   - Created relationships among tables: Demographics, Recall, Actigraph, CSAPPA, BREQ, Liking, BARSE, and ACTS_MG (name changed from ACTS-MG).
   - Built a dim_timepoint dimension to represent study phases previously unified with numbers (1, 3, 6, and 10 into Baseline, Week 3, Week 6, and Week 10)
  
2. Data Cleaning and Quality Enforcement
   - Identified and removed duplicates in key behavioral logs (Recall, BREQ, CSAPPA, etc.).
   - Standardized inconsistent identifiers (Mainly Responder_ID format, since this was the main link between the relationships among tables).
   - Enforced primary and foreign key constraints to ensure relational consistency.
   - Created unique indexes on key combinations like (Responder_ID, Week) or (Responder_ID, Week, Type).
  
3. Transformation & Derived Tables
   - Built a calculated column for total hours of sleep from Time_Go_Bed and Time_Getup_Bed in the recall table.
   - Combined all daily behavioral variables (sleep, homework, social, sports, etc.) into a v_recall_daily_summary SQL view.
   - Transformed actigraph data into a long-format view, v_total_actigraph_long, for time-series visualization.
   - Created a third column per activity in the recall table to have the total amount of hours/minutes instead of two separate columns.

4. Analysis (SQL Insights)
   - Counted participant retention across timepoints (Baseline, Week 6, Week 10).
   - Summarized average movement levels (MVPA, Light, Sedentary) per group.
   - Prepared metrics to analyze relationships between sleep, screen time, and activity.
  
![Screenshot_9-10-2025_12537_lucid app](https://github.com/user-attachments/assets/a4af6249-68e1-4d4e-85fa-e4534ca911ae)

## **Skills and tools used**
- SQL (Microsoft SQL Server): Data cleaning, schema design, relationships, constraints, indexes, and views.
- Power BI (in progress): Data modeling, visual storytelling (connected directly to SQL).
- Excel: Initial exploration and CSV preparation.
- Data Modeling: ERD design and normalization.
- Analytical Thinking: Investigating behavioral trends and data integrity

## **Results (so far)**
- Cleaned and unified the dataset of the participants tracked across multiple weeks.
- All tables linked by consistent Responder_ID keys and validated foreign constraints.
- Created analytical views ready for direct Power BI connection.
- Early SQL exploration suggests correlations between active gaming exposure and lower sedentary time, though visualization is pending.

## **The next steps**
- Finalize Power BI dashboards for behavioral and motivational analysis.
- Create calculated measures for weekly average activity per group.
- Publish findings in a data storytelling format connecting quantitative insights to behavioral implications.
- Extend the project with machine learning or predictive modeling (classifying participants likely to increase activity).
