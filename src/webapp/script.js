function onSubmit(token) {
    alert('thanks ' + document.getElementById('field').value);
}

function validate(event) {
    event.preventDefault();
    if (!document.getElementById('field').value) {
        alert("You must add text to the required field");
    } else {
        grecaptcha.execute();
    }
}

function onload() {
    var element = document.getElementById('submit');
    element.onclick = validate;
}

//////Code above is not actively used yet/////

// `upload` puts the file to the provided signed URL
function getSignedUrl() {
    document.querySelector('#status').innerHTML = '';
    var url = "https://op857sfym8.execute-api.us-east-1.amazonaws.com/beta/send";
    var filename = document.querySelector("#filename").value;
    
    var rqstOptions = {
      method: 'POST',
      body: {'fname': filename}
    };
    
    fetch(url, rqstOptions)
    .then((data) => {
        document.querySelector('#status').innerHTML = `Email sent:${data}`;
    }).catch((e) => {
        console.error(e);
    });
}

// `upload` puts the file to the provided signed URL
function upload() {
    document.querySelector('#status').innerHTML = '';
    var url = document.querySelector("#pUrl_input").value;
    var file = document.querySelector("#selector").files[0];
    
    var requestOptions = {
      method: 'PUT',
      body: file
    };
    
    fetch(url, requestOptions)
    .then(() => {
        // If multiple files are uploaded, append upload status on the next line.
        document.querySelector('#status').innerHTML += `Uploaded ${file.name}.`;
    }).catch((e) => {
        console.error(e);
    });
}