const AWS = require('aws-sdk');
const s3 = new AWS.S3({signatureVersion: 'v4'});
const bucket = 'sfcc-test-bucket'; //process.env.S3_UPLOAD_BUCKET;
const api = 'https://op857sfym8.execute-api.us-east-1.amazonaws.com/beta/rqsts'; //`${process.env.API_INVOKE_URL}/rqsts`;
const axios = require('axios').default;

//Step 1: Get a list of the files in the uploads/ pseudo-folder
async function listUploads() {
    //const listUploads = () => {
        const getListParams = {
            Bucket: 'sfcc-test-bucket', // your bucket name,
            Prefix: 'upload' // the "folder" name we want to list
        }
        return new Promise ((resolve, reject) => {
            s3.listObjectsV2(getListParams, ((err, data) => {
                // Handle any error and exit
                if (err) {
                    reject (err);
                    }
                // No error happened
                resolve (data);
            }));
        })
    }

//Step 2: Get each file's contents
async function getS3Obj(key) {
    const getObjParams = {
        Bucket: bucket, // your bucket name,
        Key: key // path to the object you're looking for
    }
    return new Promise ((resolve, reject) => {
        s3.getObject(getObjParams, ((err, data) => {
            // Handle any error and exit
            if (err) {
                reject (err);
                }
            // No error happened
            resolve (data);
        }));
    })
}

//Step 3: Turn a csv or tsv file.toString() into an object with the headers as keys
function toJSON (rawFileString, fileType) {
    const dirtyLines = rawFileString.split('\n');
    let delimiter = ',';
    if (fileType =='tsv') { 
      delimiter = '\t';
    }
    //Remove any lines that don't look like headers or data.
    const lines = dirtyLines.filter(item => item.startsWith("ADD") || item.startsWith("DELETE") || item.startsWith("action"));
    const headers = lines.slice(0, 1)[0].split(delimiter);
    return lines.slice(1, lines.length).map(line => {
      const data = line.split(delimiter);
      return headers.reduce((obj, nextKey, index) => {
        let i = data[index]
        if (i && (!(i == '\r'))) {
          obj[nextKey] = data[index]
        };
        return obj;
      }, {});
    });
  }

//Step 4: Swap out banner keys and push rows (items) to the DynamoDB
function transformAndPush(filename, content, filetype) {
  const objArray = toJSON(content,filetype);
  let dest = 'completed';
  objArray.forEach((item) => {
    let bnr = item.banner;
    if (bnr == 'Bay') { item.banner = "bdpt_prd" }
    else if (bnr == 'O5A') { item.banner = "bdkj_prd" }
    else if (bnr == 'Saks') { item.banner = "bdms_prd" }
    else if (bnr == 'All') { item.banner = "bdpt_prd,bdkj_prd,bdms_prd" };
    if (item.action = "ADD") {
      item.rqstStatus = "ADD_AMROLE";
    } else { item.rqstStatus = "DEL_ALL"};
    //Push individual requests to DynamoDB
    axios.post(api, item)
    .then((response) => {
      console.log("DB item added:", response);
    })
    .catch((error) => {
      console.error("DB item add error:", error);
      dest = "errors";
    });
  });
  moveFile(filename,dest);
}

//Step 5: move the file to the completed/ or errors/ pseudo-folder
function moveFile(filename,dest) {
    const oldPrefix = 'upload/';
    let newPrefix = 'completed/';
    if (dest == "errors") {
        newPrefix = 'errors/';
    }
    const copyParams = {
        Bucket: bucket,
        CopySource: bucket + '/' + filename,
        Key: filename.replace(oldPrefix, newPrefix)
    };
    s3.copyObject(copyParams, ((copyErr, copyData) => {
        if (copyErr) {
        console.log(copyErr);
        }
        else {
            console.log('Copied: ', copyParams.Key);
            // removing source files
            const deleteParams = {
                Bucket: bucket,
                Key: filename
            }; 
            s3.deleteObject(deleteParams, ((deleteErr, deleteData) => {
                if (deleteErr) {
                    console.log(deleteErr);
                }
                console.log('Removed: ', deleteParams.Key);
            }))
        }
    }))
}

///EXECUTION BEGINS HERE
const upldListPromise = listUploads();
upldListPromise.then((data) => {
    let allKeys = [];
    if (data.Contents.length) {
        let contents = data.Contents;
        contents.forEach((content) => {
            //don't get root object
            if (!(content.Key.endsWith('/'))) {
                allKeys.push(content.Key);
            }
        });
        if (data.IsTruncated) {
            params.ContinuationToken = data.NextContinuationToken;
            console.log("get further list...");
            listAllKeys();
        }
    }
    allKeys.forEach((key) => {
        let getObjPromise = getS3Obj(key);
        getObjPromise.then((fileContents) => {
            // Convert Body from a Buffer to a String
            // Use the encoding necessary
            let fString = fileContents.Body.toString('utf-8');
            const fname = key;
            const ftype = fname.split('.').pop().toLowerCase();
            const acceptedFiletypes = ['csv','tsv'];
            if (acceptedFiletypes.includes(ftype)) {
                transformAndPush(key, fString, ftype);
            } else {
                const destination = 'errors';
                moveFile(key, destination);
                console.error(`${key}: Please input a valid comma-separated values(CSV) or tab-separated values(TSV) file.`)
            }
        })
    });
})

