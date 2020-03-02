const uuid = require('uuid');
const joi = require('joi');
const dynamoDB = require('../dynamodb');

module.exports.handler=async(evt, ctx) =>{
    const data = JSON.parse(evt.body);
    const timestamp = new Date().toISOString();
    
    //TODO add better transforms and validation
    const schema = joi.object().keys({
        rqstStatus: joi.string()
        .alphanum()
        .min(5)
        .max(10)
        .required(),

        firstName: joi.string()
        .alphanum()
        .min(3)
        .max(30)
        .required(),
        
        lastName: joi.string()
        .alphanum()
        .min(3)
        .max(30)
        .required(),

        email: joi.string()
        .email({ minDomainSegments: 2, tlds: { allow: ['com'] } })
        .required(),

        role: joi.string().required(),
        banner: joi.string().required(),
        AMRole: joi.string().required()
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
        TableName: process.env.REQUESTS_TABLE,
        Item: {
            id: uuid.v1(),
            createdAt: timestamp,
            updatedAt: timestamp,
            rqstStatus: data.rqstStatus,
            firstName: data.firstName,
            lastName: data.lastName,
            email: data.email,
            role: data.role,
            banner: data.banner,
            AMRole: data.AMRole
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

