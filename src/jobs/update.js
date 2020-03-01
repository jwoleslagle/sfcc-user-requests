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
    const id = evt.pathParameters.id;
    const params = {
        TableName: process.env.JOBS_TABLE,
        Key: {
            id
        },
        UpdateExpression:
            'SET title= :title,published= :published,updatedAt= :updatedAt',
        ExpressionAttributeValues: {
            ':title': data.title,
            ':published': data.published,
            ':updatedAt': timestamp
        },
        ReturnValues: 'ALL_NEW'
    };
    try{
        const results = await dynamoDB.update(params).promise();
        return {
            statusCode: 200,
            body: JSON.stringify(results.Attributes)
        };
    } catch(error){
        return {
            statusCode: 500, 
            body: JSON.stringify(error)
        }
    }
}