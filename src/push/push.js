'use strict';

const fs = require('fs');
const api = `${process.env.API_INVOKE_URL}/rqsts`;
const axios = require('axios').default;

//turns a csv or tsv file.toString() into an object with the headers as keys
function toJSON(rawFileString, fileType) {
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

  
function readFile (bucketName, filename, onFileContent, onError) {
  var params = { Bucket: bucketName, Key: filename };
  s3.getObject(params, function (err, data) {
      if (!err) 
          readFileContent(filename, data.Body.toString());
      else
          console.log(err);
  });
}

function readFileContent(filename, content) {
  let rawData = content.toString('utf8');
  const objArray = toJSON(rawData,filetype);
  console.log(objArray);
  objArray.forEach((item) => {
    let bnr = item.banner;
    if (bnr == 'Bay') { item.banner = "bdpt_prd" }
    else if (bnr == 'O5A') { item.banner = "bdkj_prd" }
    else if (bnr == 'Saks') { item.banner = "bdms_prd" }
    else if (bnr == 'All') { item.banner = "bdpt_prd,bdkj_prd,bdms_prd" };
    if (item.action = "ADD") {
      item.rqstStatus = "ADD_AMROLE";
    } else { item.rqstStatus = "DEL_AMROLE"};
    //Push individual requests to DynamoDB
    axios.post(api, item)
    .then(function (response) {
      console.log(response);
    })
    .catch(function (error) {
      console.log(error);
    });

  });
  console.log(objArray);  
}

function onError (err) {
  console.log('error: ' + err);
} 

/////EXECUTION STARTS HERE
exports.handler = (event, context, callback) => {  
  const data = JSON.parse(evt.body);
  const filename = data.filename;
  const filetype = filename.split('.').pop().toLowerCase();
  const acceptedFiletypes = ['csv','tsv'];

  if (acceptedFiletypes.includes(filetype)) {
    var bucketName = process.env.S3_UPLOAD_BUCKET;
    var keyName = `/upload/${filename}`;

    readFile(bucketName, keyName, readFileContent, onError);
  } else {
      console.error('Please input a valid comma-separated values(CSV) or tab-separated values(TSV) file.')
  }
}
