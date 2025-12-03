// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Charity
 * @dev A decentralized charity platform for creating and managing donation campaigns
 */
contract Charity {
    
    struct Campaign {
        uint256 id;
        string title;
        string description;
        string imageUrl;
        uint256 goalAmount;
        uint256 raisedAmount;
        address payable owner;
        bool isActive;
        uint256 createdAt;
    }
    
    // State variables
    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public donations; // campaignId => donor => amount
    mapping(uint256 => address[]) public donors; // campaignId => list of donors
    
    address public platformOwner;
    uint256 public platformFeePercentage; // Fee in basis points (e.g., 250 = 2.5%)
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        string title,
        uint256 goalAmount,
        address indexed owner
    );
    
    event DonationReceived(
        uint256 indexed campaignId,
        address indexed donor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed owner,
        uint256 amount
    );
    
    event CampaignStatusChanged(
        uint256 indexed campaignId,
        bool isActive
    );
    
    // Modifiers
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this");
        _;
    }
    
    modifier onlyCampaignOwner(uint256 _campaignId) {
        require(campaigns[_campaignId].owner == msg.sender, "Only campaign owner can call this");
        _;
    }
    
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId > 0 && _campaignId <= campaignCount, "Campaign does not exist");
        _;
    }
    
    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        _;
    }
    
    constructor() {
        platformOwner = msg.sender;
        platformFeePercentage = 0; // 0% fee initially, can be changed
    }
    
    /**
     * @dev Create a new charity campaign
     * @param _title Title of the campaign
     * @param _description Description of the campaign
     * @param _imageUrl URL of the campaign image
     * @param _goalAmount Target amount to raise (in wei)
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        string memory _imageUrl,
        uint256 _goalAmount
    ) external returns (uint256) {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        campaignCount++;
        
        campaigns[campaignCount] = Campaign({
            id: campaignCount,
            title: _title,
            description: _description,
            imageUrl: _imageUrl,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            owner: payable(msg.sender),
            isActive: true,
            createdAt: block.timestamp
        });
        
        emit CampaignCreated(campaignCount, _title, _goalAmount, msg.sender);
        
        return campaignCount;
    }
    
    /**
     * @dev Donate to a specific campaign
     * @param _campaignId ID of the campaign to donate to
     */
    function donate(uint256 _campaignId) 
        external 
        payable 
        campaignExists(_campaignId) 
        campaignActive(_campaignId) 
    {
        require(msg.value > 0, "Donation amount must be greater than 0");
        
        Campaign storage campaign = campaigns[_campaignId];
        
        // Track new donors
        if (donations[_campaignId][msg.sender] == 0) {
            donors[_campaignId].push(msg.sender);
        }
        
        // Update donation records
        donations[_campaignId][msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;
        
        emit DonationReceived(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Withdraw funds from a campaign (campaign owner only)
     * @param _campaignId ID of the campaign
     * @param _amount Amount to withdraw (in wei)
     */
    function withdrawFunds(uint256 _campaignId, uint256 _amount) 
        external 
        campaignExists(_campaignId) 
        onlyCampaignOwner(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(campaign.raisedAmount >= _amount, "Insufficient funds in campaign");
        
        // Calculate platform fee
        uint256 platformFee = (_amount * platformFeePercentage) / 10000;
        uint256 amountAfterFee = _amount - platformFee;
        
        // Update raised amount
        campaign.raisedAmount -= _amount;
        
        // Transfer funds
        campaign.owner.transfer(amountAfterFee);
        
        if (platformFee > 0) {
            payable(platformOwner).transfer(platformFee);
        }
        
        emit FundsWithdrawn(_campaignId, msg.sender, amountAfterFee);
    }
    
    /**
     * @dev Toggle campaign active status
     * @param _campaignId ID of the campaign
     */
    function toggleCampaignStatus(uint256 _campaignId) 
        external 
        campaignExists(_campaignId) 
        onlyCampaignOwner(_campaignId) 
    {
        campaigns[_campaignId].isActive = !campaigns[_campaignId].isActive;
        emit CampaignStatusChanged(_campaignId, campaigns[_campaignId].isActive);
    }
    
    /**
     * @dev Get campaign details
     * @param _campaignId ID of the campaign
     */
    function getCampaign(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (
            uint256 id,
            string memory title,
            string memory description,
            string memory imageUrl,
            uint256 goalAmount,
            uint256 raisedAmount,
            address owner,
            bool isActive,
            uint256 createdAt
        ) 
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.id,
            campaign.title,
            campaign.description,
            campaign.imageUrl,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.owner,
            campaign.isActive,
            campaign.createdAt
        );
    }
    
    /**
     * @dev Get all active campaigns
     */
    function getActiveCampaigns() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // Count active campaigns
        for (uint256 i = 1; i <= campaignCount; i++) {
            if (campaigns[i].isActive) {
                activeCount++;
            }
        }
        
        // Create array of active campaign IDs
        uint256[] memory activeCampaignIds = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= campaignCount; i++) {
            if (campaigns[i].isActive) {
                activeCampaignIds[index] = i;
                index++;
            }
        }
        
        return activeCampaignIds;
    }
    
    /**
     * @dev Get donation amount by a specific donor to a campaign
     * @param _campaignId ID of the campaign
     * @param _donor Address of the donor
     */
    function getDonationAmount(uint256 _campaignId, address _donor) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return donations[_campaignId][_donor];
    }
    
    /**
     * @dev Get all donors for a campaign
     * @param _campaignId ID of the campaign
     */
    function getDonors(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (address[] memory) 
    {
        return donors[_campaignId];
    }
    
    /**
     * @dev Get number of donors for a campaign
     * @param _campaignId ID of the campaign
     */
    function getDonorCount(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return donors[_campaignId].length;
    }
    
    /**
     * @dev Update platform fee (platform owner only)
     * @param _newFeePercentage New fee in basis points (e.g., 250 = 2.5%)
     */
    function updatePlatformFee(uint256 _newFeePercentage) external onlyPlatformOwner {
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }
    
    /**
     * @dev Transfer platform ownership
     * @param _newOwner Address of the new platform owner
     */
    function transferPlatformOwnership(address _newOwner) external onlyPlatformOwner {
        require(_newOwner != address(0), "Invalid address");
        platformOwner = _newOwner;
    }
}
