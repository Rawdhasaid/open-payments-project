import dlt
import pandas as pd

# Read the CSV in chunks to handle the large file size efficiently
def csv_data():
    for chunk in pd.read_csv(
        'OP_DTL_GNRL_cleaned.csv',
        chunksize=100_000,
        dtype=str,          # read everything as string initially so pandas doesn't misguess types
        encoding='utf-8'
    ):
        yield chunk.to_dict(orient='records')

# Set up the pipeline
pipeline = dlt.pipeline(
    pipeline_name='open_payments_pipeline',
    destination='postgres',
    dataset_name='public'   # this becomes the schema in Postgres
)

# Run the load — dlt will infer column types automatically from the data
load_info = pipeline.run(
    csv_data(),
    table_name='open_payments_general_dlt'
)

print(load_info)