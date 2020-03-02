const joi = require('joi');
const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    const data = JSON.parse(evt.body);
    const timestamp = new Date().toISOString();
    
    const schema = joi.object().keys({
        rqstStatus: joi.string().required(),
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
        TableName: process.env.REQUESTS_TABLE,
        Key: {
            id
        },
        //Check to see if id exists, don't create new if it doesn't
        ConditionExpression:
            'id = :id',
        UpdateExpression:
            'SET rqstStatus= :rqstStatus,updatedAt= :updatedAt',
        ExpressionAttributeValues: {
            ':id': id,
            ':rqstStatus': data.rqstStatus,
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