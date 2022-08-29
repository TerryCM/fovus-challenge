const AWS = require("aws-sdk");
const dynamo = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event, context) => {
    let body;
    let statusCode = 200;
    const headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin" : "*", // Required for CORS support to work
        "Access-Control-Allow-Credentials" : true
    };

    try {
        switch (event.routeKey) {
            case "DELETE /items/{id}":
                await dynamo
                    .delete({
                        TableName: "upload-challenge-db",
                        Key: {
                            id: event.pathParameters.id
                        }
                    })
                    .promise();
                body = `Deleted item ${event.pathParameters.id}`;
                break;
            case "GET /items/{id}":
                body = await dynamo
                    .get({
                        TableName: "upload-challenge-db",
                        Key: {
                            id: event.pathParameters.id
                        }
                    })
                    .promise();
                break;
            case "GET /items":
                body = await dynamo.scan({ TableName: "upload-challenge-db" }).promise();
                break;
            case "PUT /items":
                let requestJSON = JSON.parse(event.body);
                await dynamo
                    .put({
                        TableName: "upload-challenge-db",
                        Item: {
                            id: context.awsRequestId,
                            input_text: requestJSON.input_text,
                            input_file_path: requestJSON.input_file_path,
                        }
                    })
                    .promise();
                body = `Put item with input_text ${requestJSON.input_text} and input_file_path ${requestJSON.input_file_path}`;
                break;
            case "PATCH /items/{id}":
                let requestBody = JSON.parse(event.body);
                console.log('The request body is: ' + requestBody);
                await dynamo
                    .update({
                        TableName: "upload-challenge-db",
                        Key: {
                            id: event.pathParameters.id,
                        },
                        // 'SET' means add/replace an attribute, 'REMOVE' means remove an attribute
                        UpdateExpression: "SET output_file_path = :output_file_path",
                        ExpressionAttributeValues: {
                            ":output_file_path": requestBody.output_file_path
                        }
                    })
                    .promise();
                body = `Updated item ${event.pathParameters.id}`;
                break;
            default:
                throw new Error(`Unsupported route: "${event.routeKey}"`);
        }
    } catch (err) {
        statusCode = 400;
        body = err.message;
    } finally {
        body = JSON.stringify(body);
    }

    return {
        statusCode,
        body,
        headers
    };
};

