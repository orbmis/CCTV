const { expect } = require('chai')
const { ethers } = require('hardhat')

const toWei = amount => BigInt(amount) * (10n ** 18n)

describe('Coordinator', function () {
  let contractInstance, token

  async function setup() {
    if (!contractInstance && !token) {
      const Token = await ethers.getContractFactory('Token')
      token = await Token.deploy(toWei(10000n), 'NFT Voting Token', 'VOTE').then(c => c.deployed())

      const Coordinator = await ethers.getContractFactory('Coordinator')
      contractInstance = await Coordinator.deploy(token.address, '0x000000000000000000000000000000000000dead', '0x0000000000000000000000000000000000000000').then(c => c.deployed())

      return { contractInstance, token }
    } else {
      return { contractInstance, token }
    }
  }

  it('Should initiate a new item correctly', async function () {
    const { contractInstance, token } = await setup()

    contractInstance.insertItem('0x000000000000000000000000000000000000dead', 123, 'http://example.com', 1)

    const item = await contractInstance.getItem(1)

    expect(item.numberVotes).to.equal(340282366920938463463374607431768211456n)
    expect(item.left).to.equal(0)
    expect(item.right).to.equal(0)
    expect(item.tokendata.tokenId).to.equal(123n)
    expect(item.tokendata.tokenURI).to.equal('http://example.com')
  })

  it('should a second item correctly', async function () {
    const { contractInstance, token } = await setup()

    contractInstance.insertItem('0x000000000000000000000000000000000000dead', 666, 'http://somewhere.com', 1)

    const previousItem = await contractInstance.getItem(1)
    const newItem = await contractInstance.getItem(2)

    const numberItems = await contractInstance.getNumberItems()

    expect(numberItems).to.equal(3)
    expect(previousItem.left).to.equal(2)
    expect(previousItem.right).to.equal(0)
    expect(newItem.tokendata.tokenId).to.equal(666n)
    expect(newItem.tokendata.tokenURI).to.equal('http://somewhere.com')
  })
})
