import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import UploadImageToS3WithNativeSdk from "./UploadImageToS3WithNativeSdk";
import reportWebVitals from './reportWebVitals';
import Uploader from "./Uploader";
import App from "./App";

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
      <Uploader />
  </React.StrictMode>
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
