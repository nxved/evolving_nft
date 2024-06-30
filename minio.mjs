import * as Minio from "minio";

const minioClient = new Minio.Client({
  endPoint: "141.95.126.198",
  port: 9000,
  useSSL: false,
  accessKey: "",
  secretKey: "",
});

const sourceFile = "Z:/codes/hardhat_starter/README.md";
const bucket = "metadata";
const destinationObject = "README.md";

const run = async () => {
  try {
    const exists = await minioClient.bucketExists(bucket);
    if (exists) {
      console.log("Bucket " + bucket + " exists.");
    } else {
      await minioClient.makeBucket(bucket, "us-east-1");
      console.log('Bucket "' + bucket + '" created in "us-east-1".');
    }

    const metaData = {
      "Content-Type": "text/plain",
      "X-Amz-Meta-Testing": 1234,
      example: 5678,
    };

    await minioClient.fPutObject(
      bucket,
      destinationObject,
      sourceFile,
      metaData
    );
    console.log(
      "File " +
        sourceFile +
        " uploaded as object " +
        destinationObject +
        " in bucket " +
        bucket
    );
  } catch (err) {
    console.error(err);
  }
};

run();
