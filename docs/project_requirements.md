# Course Project: End-to-End Data Analytics Pipeline on GCP

## Project Overview

Design, implement, and demonstrate a complete end-to-end data analytics pipeline using Google Cloud Platform (GCP) services. The goal is to simulate a real-world data workflow, from data ingestion to analytics and visualization.

## Core Components

- **Data Ingestion:** Pull data from a dataset (e.g., Kaggle, public datasets) or an API. This may be batch or streaming data.
- **Data Storage:** Store raw data in Google Cloud Storage.
- **Data Processing / Transformation:** Clean, transform, and prepare data for analysis or machine learning.
- **Data Warehouse:** Store processed data into BigQuery tables.
- **Analytics or Machine Learning:** Perform analysis or optionally build a machine learning model to generate insights.
- **Visualization:** Present results through appropriate visualizations (e.g., dashboards or charts in Looker Studio).
- **Pipeline Orchestration (optional):** Tools such as Google Cloud Composer can be used to automate pipeline workflows. Be mindful of costs.

---

## Project Timeline and Deliverables

### Step 1: Project Proposal (15 pts) – Due 3rd April

Submit a 1-2 page proposal as a PDF that includes:

- Your name
- Description of the dataset you plan to use (source, size, type/format, characteristics such as structured/unstructured, complexity, missing values)
- Services you plan to use (e.g., Cloud Storage, Dataproc, BigQuery, Cloud Composer, Vertex AI, etc.)
- The final product you plan to develop (analytics dashboard or machine learning model)
- Brief explanation of why your dataset is suitable for a large-scale data pipeline (e.g., too large for local processing, involves streaming, or requires integrating multiple related datasets)

### Step 2: Check-in (15 pts) – Due 24th April

Submit a short progress report (1-2 pages). The check-in ensures your project is progressing and allows feedback before the final submission. Include:

- What you have completed so far
- Any issues or challenges encountered
- Planned next steps before the final presentation

> **Note:** About 60% of your project should be completed at this stage.

### Step 3: Project Presentation / Demo (25 pts)

5 minutes to present a demo of your pipeline including dataset, services used, and final product/insights, followed by 1 minute for Q&A (6 minutes total).

**Presentation Schedule:**

- 2:30 PM class – 6th May, 3:30 PM - 5:30 PM
- 1:25 PM class – 7th May, 1 PM - 3 PM

Presentation order will be announced on Canvas prior to the presentation date.

**Your presentation should include:**

- Project goals and dataset description
- Overview of steps and services used
- Demo of your dashboard or visualization (ML results if applicable)
- Key insights and conclusions

Submit presentation slides on Canvas.

### Step 4: Project Submission (45 pts) – Due on or before 10th May

Submit a GitHub repo link and provide collaborator access.

Screenshots may be included in any subsection in the final report to illustrate your work.

---

## Final Report Requirements

1. Project overview and goals
2. Dataset description
3. Description of pipeline workflow and services used (the overall architecture)
4. Data processing steps: cleaning, transformations, and intermediate outputs (screenshots if helpful)
5. Results obtained: what tables, summaries, or processed data came out of the pipeline
6. Visualizations / dashboard
7. Challenges encountered and how they were resolved
8. Lessons learned / overview of what you learned
9. Potential next steps if more time were available

## Project Implementation

Include all relevant code, scripts, and files in your repository so your workflow can be verified.

## Evaluation Criteria

- Completeness of the end-to-end pipeline
- Appropriate use of GCP services
- Clarity of the report and documentation
- Quality of the final visualization and insights
