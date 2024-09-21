// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DACO {
    event ProjectCreated(
        uint256 projectId,
        string name,
        string description,
        uint256 goal,
        uint256 deadline,
        address spendingCause,
        address owner
    );
    event DonationReceived(uint256 projectId, address donor, uint256 amount);
    event SpendingCauseSet(uint256 projectId, address spendingCause);
    event SpendingApproved(uint256 projectId, uint256 totalApprovedAmount);
    event FundsSpent(uint256 projectId, address spendingCause, uint256 amount);

    uint256 private constant MINIMUM_APPROVAL_RATIO = 2;

    struct Project {
        string name;
        string description;
        uint256 goal;
        uint256 fundsRaised;
        bool active;
        address owner;
        address[] donors;
        mapping(address => uint256) donationAmount;
        address payable spendingCause;
        uint256 totalApprovedAmount;
        uint256 approvalVersion;
        uint256 deadline;
    }

    mapping(uint256 => Project) public projects;
    uint256 public projectCount;
    mapping(uint256 => mapping(address => uint256)) public lastApprovalVersion;

    function getDonorAmount(
        uint256 _projectId,
        address _donor
    ) public view returns (uint256) {
        return projects[_projectId].donationAmount[_donor];
    }

    function getDonors(
        uint256 _projectId
    ) public view returns (address[] memory) {
        return projects[_projectId].donors;
    }

    function createProject(
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _deadline
    ) public {
        createProject(
            _name,
            _description,
            _goal,
            _deadline,
            payable(address(0))
        );
    }

    function createProject(
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _deadline,
        address payable _spendingCause
    ) public {
        Project storage project = projects[projectCount];
        project.name = _name;
        project.description = _description;
        project.goal = _goal;
        project.fundsRaised = 0;
        project.active = true;
        project.owner = msg.sender;
        project.spendingCause = _spendingCause;
        project.approvalVersion = 1;
        project.deadline = block.timestamp + _deadline;

        projectCount++;

        emit ProjectCreated(
            projectCount - 1,
            _name,
            _description,
            _goal,
            _deadline,
            _spendingCause,
            msg.sender
        );
    }

    function donate(
        uint256 _projectId
    ) public payable deactivateAfterDeadline(_projectId) {
        Project storage project = projects[_projectId];

        require(_projectId < projectCount, "Invalid project ID");
        require(
            project.fundsRaised + msg.value <= project.goal,
            "Donation target exceeded"
        );
        require(msg.value > 0, "Donation must be greater than zero");

        project.fundsRaised += msg.value;

        if (project.donationAmount[msg.sender] == 0) {
            project.donors.push(msg.sender);
        }
        project.donationAmount[msg.sender] += msg.value;

        emit DonationReceived(_projectId, msg.sender, msg.value);
    }

    function setSpendingCause(
        uint256 _projectId,
        address payable _spendingCause
    ) public deactivateAfterDeadline(_projectId) {
        Project storage project = projects[_projectId];

        require(_projectId < projectCount, "Invalid project ID");
        require(msg.sender == project.owner, "You are not permitted");
        require(
            _spendingCause != project.spendingCause,
            "Spending cause already set to this address"
        );

        project.approvalVersion += 1;
        project.totalApprovedAmount = 0;
        project.spendingCause = _spendingCause;

        emit SpendingCauseSet(_projectId, _spendingCause);
    }

    function approveSpending(
        uint256 _projectId
    ) public deactivateAfterDeadline(_projectId) {
        Project storage project = projects[_projectId];

        require(_projectId < projectCount, "Invalid project ID");
        require(project.donationAmount[msg.sender] > 0, "No donation made");
        require(
            lastApprovalVersion[_projectId][msg.sender] !=
                project.approvalVersion,
            "Already approved"
        );

        lastApprovalVersion[_projectId][msg.sender] = project.approvalVersion;
        project.totalApprovedAmount += project.donationAmount[msg.sender];

        emit SpendingApproved(_projectId, project.totalApprovedAmount);
    }

    function spendDonations(
        uint256 _projectId
    ) public deactivateAfterDeadline(_projectId) {
        Project storage project = projects[_projectId];

        require(_projectId < projectCount, "Invalid project ID");
        require(
            project.spendingCause != address(0),
            "Spending cause address not set"
        );
        require(
            project.owner == msg.sender,
            "You can not initiate the spending"
        );
        require(
            MINIMUM_APPROVAL_RATIO * project.totalApprovedAmount >=
                project.goal,
            "Insufficient approved funds"
        );

        project.spendingCause.transfer(project.fundsRaised);

        emit FundsSpent(_projectId, project.spendingCause, project.fundsRaised);

        project.fundsRaised = 0;
        project.totalApprovedAmount = 0;
        project.active = false;
    }

    function checkAndRefundIfDeadlinePassed(uint256 _projectId) public {
        Project storage project = projects[_projectId];

        if (block.timestamp > project.deadline) {
            refundDonations(_projectId);
        }
    }

    function refundDonations(uint256 _projectId) internal {
        Project storage project = projects[_projectId];

        uint256 donation = project.donationAmount[msg.sender];
        require(donation > 0, "No donations to refund");

        payable(msg.sender).transfer(donation);

        project.donationAmount[msg.sender] = 0;
    }

    modifier deactivateAfterDeadline(uint256 _projectId) {
        Project storage project = projects[_projectId];
        require(project.active, "Project is not active");
        if (block.timestamp >= project.deadline) {
            project.active = false;
            revert("Project is no longer active due to passed deadline.");
        }
        _;
    }
}
