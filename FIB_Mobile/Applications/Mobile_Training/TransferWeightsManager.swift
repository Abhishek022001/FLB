//
//  TransferWeights.swift
//  mlx-swift-examples
//
//  Created by yunxijun on 2024/9/7.
//

import Foundation
import web3swift
import Web3Core
import BigInt

struct CIDReponse: Codable {
    var blockNumber: Int
    var transactionHash: String
}

struct CIDRequst: Codable {
    var cid: String
}

let useAPI = true;

class TransferWeightsManager
{
    class func uploadJSONToIPFS(jsonData: String, authToken: String, urlString: String, completion: ((Result<String, Error>) -> Void)?) async -> CIDReponse? {
        // 1. 创建 URL 对象
        guard let url = URL(string: urlString) else {
            completion?(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return nil
        }
        
        // 2. 创建 URLRequest 对象
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        // 3. 创建 Multipart Form Data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = NSMutableData()
        
        // Append JSON data to the multipart form data
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"data.json\"\r\n")
        body.appendString("Content-Type: application/json\r\n\r\n")
        body.appendString(jsonData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        
        request.httpBody = body as Data
        
        // 4. 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let responseBodyString = String(data: data, encoding: .utf8) {
                print("Response Body as String: \(responseBodyString)")
                
                // 尝试将字符串解析为 JSON
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("Response Body as JSON: \(json)")
                        if let cid = json["Hash"] as? String {
                            // replace to api request to upload cid
                            completion?(.success(cid))
                            if useAPI {
                                return await uploadCid(cid: cid)
                            }
                            else {
                                await call_smart_contract(weightDict: ["cid": cid])
                                return nil
                            }
                        } else {
                            completion?(.failure(NSError(domain: "Failed to find 'Hash' in JSON", code: 0, userInfo: nil)))
                        }
                    } else {
                        // JSON 解析成功，但不是字典类型
                        completion?(.failure(NSError(domain: "Response is not a valid JSON dictionary", code: 0, userInfo: nil)))
                    }
                } catch {
                    // JSON 解析失败，响应体不是有效的 JSON
                    print("Failed to parse JSON. Response Body: \(responseBodyString)")
                    completion?(.failure(NSError(domain: "Failed to parse JSON", code: 0, userInfo: nil)))
                }
            } else {
                print("Failed to convert response data to string.")
                completion?(.failure(NSError(domain: "Failed to convert response data to string", code: 0, userInfo: nil)))
            }
        }
        catch {
            print("uploadJSONToIPFS error")
        }
        return nil
    }

    class func call_smart_contract(weightDict: [String: Any]) async {
           // 读取配置文件
           guard let configURL = Bundle.main.url(forResource: "config", withExtension: "json"),
                 let configData = try? Data(contentsOf: configURL),
                 let config = try? JSONSerialization.jsonObject(with: configData, options: []) as? [String: Any] else {
               print("Failed to load config file")
               return
           }
           
           guard let rpc = config["url"] as? String,
                 let contractAddress = config["contract_address"] as? String,
                 let privateKey = config["admin_private_key"] as? String,
                 let userAddress = config["user_address"] as? String,
                 let userPrivateKey = config["user_private_key"] as? String else {
               print("Missing configuration values")
               return
           }
           
           // 读取 ABI 文件
           guard let abiURL = Bundle.main.url(forResource: "abi", withExtension: "json") else {
               print("Failed to load ABI file")
               return
           }
        let abiDataString = try? String(contentsOf: abiURL) 
        
        let provider = try? await Web3HttpProvider.init(url: URL(string: rpc)!, network: Networks.Custom(networkID: "333333333"))
        
        if provider == nil
        {
            print("init provider error")
            return
        }
           
        let web3 = Web3(provider:provider!)
 
           // 验证连接
//           guard web3.isConnected else {
//               print("Failed to connect to Ethereum node")
//               return
//           }
           
           // 创建合约实例
        let contract = web3.contract(abiDataString ?? "", at: EthereumAddress(from: contractAddress))
         
        if contract == nil
        {
            print("init contract error")
            return
        }
        
           // 发送代币到用户
        
        let keystore = try! EthereumKeystoreV3(password: privateKey)
        let keystoreManager = KeystoreManager([keystore!])
        web3.addKeystoreManager(keystoreManager)
        var tokenTransaction: CodableTransaction = CodableTransaction.init(to: EthereumAddress(userAddress)!)
        tokenTransaction.from = EthereumAddress(contractAddress)
        tokenTransaction.value = Web3Core.Utilities.parseToBigUInt("1.0", units: .ether)!
        tokenTransaction.gasLimit = BigUInt(21000)
        tokenTransaction.gasPrice = BigUInt(20000000000)
        tokenTransaction.nonce = try! await web3.eth.getTransactionCount(for: contract!.contract.address!)
        do
        {
            let tokenTransactionResult = try await web3.eth.send(tokenTransaction)
            do {
                let tokenTransactionReceipt = try await web3.eth.transactionReceipt(tokenTransactionResult.hash.data(using: .utf8)!)
                print("Send token success, receipt: \(tokenTransactionReceipt)")
            } catch {
                print("Failed to send token: \(error)")
                return
            }
        } catch
        {
            print("Send callTransaction Error")
            return
        }
        
        let keyUserstore = try! EthereumKeystoreV3(password: userPrivateKey)
        let keyUserstoreManager = KeystoreManager([keystore!])
        web3.addKeystoreManager(keystoreManager)
           
        let writeOperation = contract?.createWriteOperation("uploadUserData", parameters: [weightDict])
           // 上传用户数据
        do {
            
            var noncePolicy: NoncePolicy = .exact(try await web3.eth.getTransactionCount(for: EthereumAddress(from: userAddress)!))
            var policies: Policies = Policies.init(noncePolicy: noncePolicy, gasLimitPolicy: .manual(100000), gasPricePolicy: .automatic)
            
            let writeUserDataTransactionResult = try await writeOperation?.writeToChain(password: userPrivateKey, policies: policies)
            let uploadUserDataTransaction = writeUserDataTransactionResult?.transaction
            let uploadUserDataTransactionResult = try await web3.eth.send(uploadUserDataTransaction!)
            let uploadUserDataTransactionReceipt = try await web3.eth.transactionReceipt(uploadUserDataTransactionResult.hash.data(using: .utf8)!)
            print("Record weight success, receipt: \(uploadUserDataTransactionReceipt)")
            
        } catch
        {
            print("Failed to record weight: \(error)")
            return
        }
           
           // 可选：获取用户数据
           // let dataCount = try? contract?.call(method: "getUserDataCount", parameters: [userAccount.address])
           // let latestData = try? contract?.call(method: "getUserData", parameters: [userAccount.address, dataCount - 1])
       }
    
    class func uploadCid(cid: String) async -> CIDReponse?
    {

        let url = URL(string: "https://smart.test.cerboai.com/call_smart")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let parameters = CIDRequst(cid: cid)
        let data = try! JSONEncoder().encode(parameters)
        request.httpBody = data
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            // 使用 JSONDecoder 解析数据
            let decoder = JSONDecoder()
            let cidRes = try? decoder.decode(CIDReponse.self, from: data)
            return cidRes
        }
        catch {
            return nil
        }
    }

}

extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: String.Encoding.utf8) {
            append(data)
        }
    }
}
