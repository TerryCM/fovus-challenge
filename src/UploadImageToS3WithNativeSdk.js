import React, {useEffect} from 'react';



const {
    S3Client,
    PutObjectCommand,
} = require("@aws-sdk/client-s3");

const S3_BUCKET = process.env.REACT_APP_S3_BUCKET;
const REGION =  process.env.REACT_APP_AWS_REGION;
const API_URL = process.env.REACT_APP_API_URL;

// get acceskeyid and secretaccesskey from .env file
const s3 = new S3Client({
    region: REGION,
    credentials: {
        accessKeyId: process.env.REACT_APP_AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.REACT_APP_AWS_SECRET_ACCESS_KEY,
    }
});

const UploadImageToS3WithNativeSdk = (file, inputText) => {
    const params = {
        Bucket: S3_BUCKET,
        Key: file.name,
        Body: file,
    };


   s3.send(new PutObjectCommand(params), (err, data) => {
        if (err) {
            console.log(err);
        } else {
            console.log(data);
        }
    });

    const requestOptions = {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json',
            'Origin': 'http://localhost:3000',
        },
        body: JSON.stringify({ input_text: inputText, input_file_path: S3_BUCKET + '/' + file.name })
    };

    fetch(API_URL + '/items', requestOptions)
        .then(response => response.json())
        .then(data => console.log(data));

};


export default UploadImageToS3WithNativeSdk;