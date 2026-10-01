import dlt
from dlt.sources.filesystem import filesystem, read_csv_duckdb


DATA_FOLDER = r"C:\Users\RawdhaAlYahyai\Open_payments\open-payments-project\Data"
FILE_NAME = "OP_DTL_GNRL_PGYR2025_P06302026_06032026.csv"


files = filesystem(
    bucket_url=DATA_FOLDER,
    file_glob=FILE_NAME
)

payments = (
    files
    | read_csv_duckdb(
        chunk_size=100_000,
        use_pyarrow=True
    )
).with_name("general_payments_2025")


pipeline = dlt.pipeline(
    pipeline_name="open_payments_pipeline",
    destination=dlt.destinations.postgres(
        naming_convention="direct"
    ),
    dataset_name="raw"
)

print("Starting fast load...")

info = pipeline.run(
    payments,
    write_disposition="replace",
    loader_file_format="csv"
)

print(info)