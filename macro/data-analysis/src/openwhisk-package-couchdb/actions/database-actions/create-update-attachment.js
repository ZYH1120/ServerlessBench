/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Create and update attachment for document in Cloudant database:
 * https://docs.couchdb.com/attachments.html#create-/-update
 **/

function main(message) {
  var couchdbOrError = getCouchdb(message);
  if (typeof couchdbOrError !== 'object') {
    return Promise.reject(couchdbOrError);
  }
  var couchdb = couchdbOrError;
  var dbName = message.dbname;
  var docId = message.docid;
  var attName = message.attachmentname;
  var att = message.attachment;
  var contentType = message.contenttype;
  var params = {};

  if(!dbName) {
    return Promise.reject('dbname is required.');
  }
  if(!docId) {
    return Promise.reject('docid is required.');
  }
  if(!attName) {
    return Promise.reject('attachmentname is required.');
  }
  if(!att) {
    return Promise.reject('attachment is required.');
  }
  if(!contentType) {
    return Promise.reject('contenttype is required.');
  }
  //Add document revision to query if it exists
  if(typeof message.docrev !== 'undefined') {
    params.rev = message.docrev;
  }
  var couchdb = couchdb.use(dbName);

  if (typeof message.params === 'object') {
    params = message.params;
  } else if (typeof message.params === 'string') {
    try {
      params = JSON.parse(message.params);
    } catch (e) {
      return Promise.reject('params field cannot be parsed. Ensure it is valid JSON.');
    }
  }

  return insert(couchdb, docId, attName, att, contentType, params);
}

/**
 * Insert attachment for document in database.
 */
function insert(couchdb, docId, attName, att, contentType, params) {
  return new Promise(function(resolve, reject) {
    couchdb.attachment.insert(docId, attName, att, contentType, params, function(error, response) {
      if (!error) {
        resolve(response);
      } else {
        reject(error);
      }
    });
  });
}

function getCouchdb(message) {
    var couchdbUrl = message.url;

    return require('nano')({
        url: couchdbUrl
    });
}
