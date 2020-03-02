var handleFormSubmit = function () {
    var formApiEndpoint = 'https://n6d16pkfx9.execute-api.us-east-1.amazonaws.com/dev/send'
    var successEl = document.querySelector('.form__success')
    var sendingEl = document.querySelector('.form__sending')
    var errorsEl = document.querySelector('.form__errors')
    var buttonEl = document.querySelector('.form__button')
    var nameInput = document.querySelector('#name_input')
    var messageInput = document.querySelector('#message_input')
    var recaptchaResponse = document.querySelector('#form textarea[name=\'g-recaptcha-response\']')

    successEl.style.display = 'none'
    errorsEl.style.display = 'none'

    if (filenameInput == '') {
        errorsEl.style.display = 'block'
        buttonEl.style.display = 'block'
        sendingEl.style.display = 'none'
    } else {
        var formRequest = new Request(formApiEndpoint, {
        method: 'POST',
        body: JSON.stringify({
            fname: filenameInput.value,
            'g-recaptcha-response': recaptchaResponse.value
        })
        })

        fetch(formRequest)
        .then(function(response) {
            if (response.status === 200) {
            return response.json()
            } else {
            throw new Error('Something went wrong on api server!')
            }
        })
        .then(function(response) {
            successEl.style.display = 'block'
            buttonEl.style.display = 'block'
            sendingEl.style.display = 'none'
            nameInput.value = ''
            messageInput.value = ''
        }).catch(function(error) {
            errorsEl.style.display = 'block'
            buttonEl.style.display = 'block'
            sendingEl.style.display = 'none'
            console.error(error)
        })
    }
    }

    document.querySelector('.form__button').addEventListener('click', function() {
    document.querySelector('.form__sending').style.display = 'block'
    document.querySelector('.form__button').style.display = 'none'
})


/////////////////////////


  // `upload` iterates through all files selected and invokes a helper function called `retrieveNewURL`.
  function upload() {
    // Get selected files from the input element.
    var files = document.querySelector("#selector").files;
    for (var i = 0; i < files.length; i++) {
        var file = files[i];
        // Retrieve a URL from our server.
        retrieveNewURL(file, (file, url) => {
            // Upload the file to the server.
            uploadFile(file, url);
        });
    }
}

// `retrieveNewURL` accepts the name of the current file and invokes the `/presignedUrl` endpoint to
// generate a pre-signed URL for use in uploading that file: 
function retrieveNewURL(file, cb) {
    fetch(`/presignedUrl?name=${file.name}`).then((response) => {
        response.text().then((url) => {
            cb(file, url);
        });
    }).catch((e) => {
        console.error(e);
    });
}

// ``uploadFile` accepts the current filename and the pre-signed URL. It then uses `Fetch API`
// to upload this file to S3 at `play.min.io:9000` using the URL:
function uploadFile(file, url) {
    if (document.querySelector('#status').innerText === 'No uploads') {
        document.querySelector('#status').innerHTML = '';
    }
    fetch(url, {
        method: 'PUT',
        body: file
    }).then(() => {
        // If multiple files are uploaded, append upload status on the next line.
        document.querySelector('#status').innerHTML += `<br>Uploaded ${file.name}.`;
    }).catch((e) => {
        console.error(e);
    });
}