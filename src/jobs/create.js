const AWS = require('aws-sdk');
const uuid = require('uuid');
const joi = require('joi');
const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    const data = JSON.parse(evt.body);
    const timestamp = new Date().toISOString();
    
    const schema = joi.object().keys({
        title: joi.string().required(),
        published: joi.boolean().required()
    });

    try{
        const {error, value} = joi.validate(data,schema);
    }
    catch(err) {
        return {
            status: 400,
            body: JSON.stringify(err.details)
        }
    }

    const params = {
        TableName: process.env.JOBS_TABLE,
        Item: {
            id: uuid.v1(),
            title: data.title,
            published: data.published,
            createdAt: timestamp,
            updatedAt: timestamp
        }
    };
    try{
        await dynamoDB.put(params).promise();
        return {
            statusCode: 200,
            body: JSON.stringify(params.Item)
        };
    } catch(error){
        return {
            statusCode: 500, 
            body: JSON.stringify(error)
        }
    }
}

