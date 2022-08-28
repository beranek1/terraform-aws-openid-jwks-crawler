const https = require('https');
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
// List of OIDC providers
let oidc_providers = JSON.parse(process.env.oidc_providers);
// Source S3 bucket name
let src_bucket_name = process.env.src_bucket_name;
// Source S3 bucket path for input files
let src_bucket_path = process.env.src_bucket_path;
// Destination S3 bucket name
let dest_bucket_name = process.env.dest_bucket_name;
// Destination S3 bucket path for output files
let dest_bucket_path = process.env.dest_bucket_path;

// Fetches JWKS json file for OIDC provider at given uri (Adapted from https://nodejs.org/dist/latest-v16.x/docs/api/http.html#httpgetoptions-callback)
let fetch_jwks_configuration = function (provider, jwks_uri) {
  return new Promise(function (resolve, reject) {
    https.get(jwks_uri, (res) => {
      const { statusCode } = res;
      const contentType = res.headers['content-type'];

      let error;
      // Any 2xx status code signals a successful response but
      // here we're only checking for 200.
      if (statusCode !== 200) {
        error = new Error('Request Failed.\n' +
          `Status Code: ${statusCode}`);
      } else if (!/^application\/json/.test(contentType) && !/^text\/json/.test(contentType)) {
        error = new Error('Invalid content-type.\n' +
          `Expected application/json or text/json but received ${contentType}`);
      }
      if (error) {
        console.error(error.message);
        // Consume response data to free up memory
        res.resume();
        reject(error);
      }

      res.setEncoding('utf8');
      let rawData = '';
      res.on('data', (chunk) => { rawData += chunk; });
      res.on('end', () => {
        try {
          // Parse JSON to check syntax and eventually do some preprocessing or formating later on
          const parsedData = JSON.parse(rawData);
          resolve({ provider: provider, configuration: parsedData });
        } catch (e) {
          console.error(e.message);
          reject(Error(e));
        }
      });
    }).on('error', (e) => {
      reject(Error(e))
    })
  });
};

let get_openid_configuration = function (provider) {
  return new Promise(function (resolve, reject) {
    try {
      const srcparams = {
        Bucket: src_bucket_name,
        Key: src_bucket_path + "" + provider
      };
      s3.getObject(srcparams, function (err, data) {
        if (err) {
          reject(Error(err))
        } else {
          const parsedData = JSON.parse(data.Body.toString());
          resolve({ provider: provider, configuration: parsedData });
        }
      });
    } catch (e) {
      console.error(e.message);
      reject(Error(e));
    }
  });
}

exports.handler = async function (event) {
  const promise = new Promise(function (resolve, reject) {
    let openid_promises = oidc_providers.map(provider => get_openid_configuration(provider));
    Promise.allSettled(openid_promises).then((openid_results) => {
      let jwks_promises = [];
      openid_results.forEach((result) => {
        if (result.status == "fulfilled") {
          let provider = result.value.provider;
          let jwks_uri = result.value.configuration.jwks_uri;
          jwks_promises.push(fetch_jwks_configuration(provider, jwks_uri));
        }
      });
      Promise.allSettled(jwks_promises).then((jwks_results) => {
        let s3_promises = [];
        jwks_results.forEach((result) => {
          if (result.status == "fulfilled") {
            try {
              const destparams = {
                Bucket: dest_bucket_name,
                Key: dest_bucket_path + "" + result.value.provider,
                Body: JSON.stringify(result.value.configuration),
                ContentType: "application/json"
              };
              s3_promises.push(s3.putObject(destparams).promise());
            } catch (error) {
              console.log(error);
            }
          }
        });
        Promise.all(s3_promises).then((s3_results) => resolve(s3_results));
      });
    });
  });
  return promise;
};
