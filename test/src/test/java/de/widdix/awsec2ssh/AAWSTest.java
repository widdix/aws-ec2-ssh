package de.widdix.awsec2ssh;

import com.amazonaws.auth.*;
import com.amazonaws.services.ec2.AmazonEC2;
import com.amazonaws.services.ec2.AmazonEC2ClientBuilder;
import com.amazonaws.services.ec2.model.*;
import com.amazonaws.services.identitymanagement.AmazonIdentityManagement;
import com.amazonaws.services.identitymanagement.AmazonIdentityManagementClientBuilder;
import com.amazonaws.services.identitymanagement.model.*;
import com.amazonaws.services.securitytoken.AWSSecurityTokenService;
import com.amazonaws.services.securitytoken.AWSSecurityTokenServiceClientBuilder;
import com.jcraft.jsch.JSch;
import com.jcraft.jsch.JSchException;
import com.jcraft.jsch.KeyPair;

import java.io.ByteArrayOutputStream;
import java.util.List;
import java.util.UUID;

public abstract class AAWSTest extends ATest {

    public final static String IAM_SESSION_NAME = "aws-ec2-ssh";

    protected final AWSCredentialsProvider credentialsProvider;

    private AmazonEC2 ec2;

    private AmazonIdentityManagement iam;

    public AAWSTest() {
        super();
        if (Config.has(Config.Key.IAM_ROLE_ARN)) {
            final AWSSecurityTokenService sts = AWSSecurityTokenServiceClientBuilder.standard().withCredentials(new DefaultAWSCredentialsProviderChain()).build();
            this.credentialsProvider = new STSAssumeRoleSessionCredentialsProvider.Builder(Config.get(Config.Key.IAM_ROLE_ARN), IAM_SESSION_NAME).withStsClient(sts).build();
        } else {
            this.credentialsProvider = new DefaultAWSCredentialsProviderChain();
        }
        this.ec2 = AmazonEC2ClientBuilder.standard().withCredentials(this.credentialsProvider).build();
        this.iam = AmazonIdentityManagementClientBuilder.standard().withCredentials(this.credentialsProvider).build();
    }

    protected final User createUser(final String userName) throws JSchException {
        final JSch jsch = new JSch();
        final KeyPair keyPair = KeyPair.genKeyPair(jsch, KeyPair.RSA, 2048);
        final ByteArrayOutputStream osPublicKey = new ByteArrayOutputStream();
        final ByteArrayOutputStream osPrivateKey = new ByteArrayOutputStream();
        keyPair.writePublicKey(osPublicKey, userName);
        keyPair.writePrivateKey(osPrivateKey);
        final byte[] sshPrivateKeyBlob = osPrivateKey.toByteArray();
        final String sshPublicKeyBody = osPublicKey.toString();
        this.iam.createUser(new CreateUserRequest().withUserName(userName));
        final UploadSSHPublicKeyResult res = this.iam.uploadSSHPublicKey(new UploadSSHPublicKeyRequest().withUserName(userName).withSSHPublicKeyBody(sshPublicKeyBody));
        return new User(userName, sshPrivateKeyBlob, res.getSSHPublicKey().getSSHPublicKeyId());
    }

    protected final void deleteUser(final String userName) {
        if (Config.get(Config.Key.DELETION_POLICY).equals("delete")) {
            final ListSSHPublicKeysResult res = this.iam.listSSHPublicKeys(new ListSSHPublicKeysRequest().withUserName(userName));
            this.iam.deleteSSHPublicKey(new DeleteSSHPublicKeyRequest().withUserName(userName).withSSHPublicKeyId(res.getSSHPublicKeys().get(0).getSSHPublicKeyId()));
            this.iam.deleteUser(new DeleteUserRequest().withUserName(userName));
        }
    }

    protected final Vpc getDefaultVPC() {
        final DescribeVpcsResult res = this.ec2.describeVpcs(new DescribeVpcsRequest().withFilters(new Filter().withName("isDefault").withValues("true")));
        return res.getVpcs().get(0);
    }

    protected final List<Subnet> getDefaultSubnets() {
        final DescribeSubnetsResult res = this.ec2.describeSubnets(new DescribeSubnetsRequest().withFilters(new Filter().withName("defaultForAz").withValues("true")));
        return res.getSubnets();
    }

    protected final SecurityGroup getDefaultSecurityGroup() {
        final Vpc vpc = this.getDefaultVPC();
        final DescribeSecurityGroupsResult res = this.ec2.describeSecurityGroups(new DescribeSecurityGroupsRequest().withFilters(
                new Filter().withName("vpc-id").withValues(vpc.getVpcId()),
                new Filter().withName("group-name").withValues("default")
        ));
        return res.getSecurityGroups().get(0);
    }

    protected final String random8String() {
        final String uuid = UUID.randomUUID().toString().replace("-", "").toLowerCase();
        final int beginIndex = (int) (Math.random() * (uuid.length() - 7));
        final int endIndex = beginIndex + 7;
        return "r" + uuid.substring(beginIndex, endIndex); // must begin [a-z]
    }

}
