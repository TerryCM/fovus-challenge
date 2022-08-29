import {useState} from "react";
import UploadImageToS3WithNativeSdk from "./UploadImageToS3WithNativeSdk";


const Uploader = () => {
    const [progress, setProgress] = useState(0);
    const [selectedFile, setSelectedFile] = useState(null);
    const [inputText, setInputText] = useState("");

    const handleFileInput = (e) => {
        setSelectedFile(e.target.files[0]);
    }

    const handleInputText = (e) => {
        setInputText(e.target.value);
    }
    return (
        // div should be in the center of the screen
        <div className="block p-10 rounded-lg shadow-lg bg-white max-w-sm mx-auto">
            <label htmlFor="inputText" className="form-label inline-block mb-2 text-gray-700"
            >Text Input</label>

            <input className="form-control
        block
        w-full
        px-3
        py-1.5
        text-base
        font-normal
        text-gray-700
        bg-white bg-clip-padding
        border border-solid border-gray-300
        rounded
        transition
        ease-in-out
        m-0
        focus:text-gray-700 focus:bg-white focus:border-blue-600 focus:outline-none" type="text" onChange={handleInputText} value={inputText} id="inputText" />
            <br />

            <label htmlFor="fileInput" className="form-label inline-block mb-2 text-gray-700"
            >File Input</label>
            <input className="form-control
    block
    w-full
    px-3
    py-1.5
    text-base
    font-normal
    text-gray-700
    bg-white bg-clip-padding
    border border-solid border-gray-300
    rounded
    transition
    ease-in-out
    m-0
    focus:text-gray-700 focus:bg-white focus:border-blue-600 focus:outline-none" type="file" id="fileInput" onChange={handleFileInput} />
            <br />

            <button className="inline-block px-6 py-3 w-full bg-gray-800 text-white font-medium text-xs leading-tight uppercase rounded shadow-md hover:bg-gray-900 hover:shadow-lg focus:bg-gray-900 focus:shadow-lg focus:outline-none focus:ring-0 active:bg-gray-900 active:shadow-lg transition duration-150 ease-in-out bg-clip-padding" onClick={() => UploadImageToS3WithNativeSdk(selectedFile, inputText)}>Submit</button>
            {/*<div className="w-full bg-gray-200 h-1">*/}
            {/*    <div className="bg-blue-600 h-1" style="width: 45%"></div>*/}
            {/*</div>*/}
</div>
    );
}

export default Uploader;