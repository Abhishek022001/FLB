Language: [[English]](../chain/README.md) [[中文]](./README-Chain-cn.md)

### 概览
这是一个[solidity](https://soliditylang.org/)语言开发的智能合约项目，用于记录用户训练数据和用户得分，使用的区块链平台是和EVM虚拟机兼容的Cerbo Chain。

运行该项目需要有[Node.js](https://nodejs.org/en) v20.16.0 及以上版本

### 合约代码分析
基于Hardhat框架，我们开发了一个智能合约，该合约实现了记录用户训练数据和用户得分的功能，就在`contracts/FLB.sol`文件中。

#### 合约基础结构：
合约 FLB 继承自 openzeppelin 的 Ownable 库，这意味着合约的所有者（管理员）具有特殊权限。
#### 数据存储：
使用 EnumerableMap 来存储用户的分数，允许高效的插入、删除和查找操作。  
dataUploaded 映射用于记录某个数据是否已经上传，防止重复上传。    
userDataSet 数组存储每个用户上传的数据，便于后续检索。
#### 事件：
ScoreAdd 事件在管理员更新用户分数时触发，记录相关信息。  
DataUpload 事件在用户上传数据时触发，记录上传者的地址。
#### 构造函数：
构造函数接受一个地址作为初始管理员，并通过 Ownable 进行初始化。这样合约的所有者可以管理用户的分数。
#### 核心功能：
addScore：只有管理员可以调用此方法，允许其为指定用户增加分数。通过 tryGet 方法获取当前分数，如果用户不存在则初始化为 0。  
uploadUserData：用户可以上传数据，但需确保数据未被上传过。若数据上传成功，用户的分数会被初始化为 0（如果尚不存在）。  
userExists：检查用户是否存在于系统中。  
getScore：返回指定用户的分数，若用户不存在则返回 0。  
getUserData 和 getUserDataCount：提供用户上传数据的检索功能。  
getUserCount 和 getUserScore：用于获取当前用户的数量和按索引获取用户分数。

```solidity
contract FLB is Ownable {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private scores;   // storing user scores
    mapping(string => bool) private dataUploaded;    // record data is uploaded
    mapping(address => string[]) public userDataSet; // storing user upload data

    // Event, used to record score add
    /**
     * @dev ScoreAdd defines an Event emitted when admin update user's score.
     */
    event ScoreAdd(address indexed user, uint256 newScore);
    /**
     * @dev DataUpload defines an Event emitted when user updaload his local data for train.
     */
    event DataUpload(address indexed user);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev addScore defines admin update user's score.
     */
    function addScore(address user, uint256 score) public onlyOwner {
        (bool find, uint256 preScore) = scores.tryGet(user);
        scores.set(user, find ? preScore + score : score);
        emit ScoreAdd(user, score); // Triggering Events
    }

    /**
     * @dev uploadUserData defines user updaload his local data for train.
     */
    function uploadUserData(string memory data) public {
        require(!dataUploaded[data], "Data already uploaded");

        userDataSet[msg.sender].push(data);
        dataUploaded[data] = true;

        if (!scores.contains(msg.sender)) {
            scores.set(msg.sender, 0);
        }

        emit DataUpload(msg.sender);
    }
}
```

### 合约测试

因为本项目基于Hardhat框架开发，所以可以在本地进行合约测试，主要是验证合约的功能是否正常。

`cd ./contract/`

1. 安装 NPM

`npm install`

2. 编译智能合约

`npx hardhat compile`

3. 启动本地网络  
   运行此命令会在本地启动一个单节点的区块链网络，用于部署和测试合约。

`npx hardhat node`

4. 打开一个新的终端，通过自动生成的管理员账户部署智能合约到本地网络。

`npx hardhat run --network localhost scripts/deployFLB.js`

5. 终端显示以下内容，表示合约已成功部署

```
Deploying contracts with the account: 0x00000Be6819f41400225702D32d3dd23663Dd690
Account balance: 100000000000000000000000000000000000000000000000000000
flb address: 0x546bc6E008689577C69C42b9C1f6b4C923f59B5d
0x00000Be6819f41400225702D32d3dd23663Dd690 have score 100
```

6. 运行测试  
   通过已经在本地区块链网络上部署好的合约，运行以下命令进行合约的功能测试

`npx hardhat test`

要运行特定的测试文件，可以使用以下命令：

`npx hardhat test ./test/flb.js`

7. 终端显示以下信息，表明合约已测试成功。从打印的信息可以看出，在管理员调用合约`addScore`方法，抛出合约event，非管理员无法调用`addScore`方法这些测试用例都是通过的。

```
Deploying contracts with the account: 0x00000Be6819f41400225702D32d3dd23663Dd690
Account balance: 100000000000000000000000000000000000000000000000000000
flb address: 0x546bc6E008689577C69C42b9C1f6b4C923f59B5d
0x00000Be6819f41400225702D32d3dd23663Dd690 have score 100
➜  contract git:(main) ✗ npx hardhat test ./test/flb.js


  FLB
flb address: 0x33Add53fb1CDeF4A10BeE7249b66a685200DDd2f
    ✔ Should add score record
    ✔ Should add score record and emit event
    ✔ Should accumulate score when adding multiple times
    ✔ Should not allow non-admin to add score


  4 passing (139ms)
```

### 运行示例
这里我们已经准备好了一个示例，在Cerbo Chain中已经部署好了FLB合约，可以通过以下命令运行示例，
在这个示例中，我们调用了合约的`addScore`方法，向合约中添加分数，调用了`uploadUserData`方法，上传本地数据，以及对应的查询方法。

`cd ./contract/sample`

1. 安装依赖

`npm install`

2. 如有必要，修改配置文件`config.json`

3. 运行示例

`node flb.js`

### 验证合约代码

`npx hardhat verify --network cerbo 0xfF45Ac560476aEd6F7794f0e835b61d95e5d1C21 0x00000Be6819f41400225702D32d3dd23663Dd690 --show-stack-traces --force`

### 在区块浏览器上查看

[https://dev-scan.cerboai.com/address/0xfF45Ac560476aEd6F7794f0e835b61d95e5d1C21?tab=txs](https://dev-scan.cerboai.com/address/0xfF45Ac560476aEd6F7794f0e835b61d95e5d1C21?tab=txs)