package de.widdix.awsec2ssh;

import com.amazonaws.services.cloudformation.model.Parameter;
import org.junit.Test;

public class TestShowcase extends ACloudFormationTest {

    @Test
    public void testUbuntu() throws Exception {
        final String stackName = "showcase-" + this.random8String();
        final String userName = "user-" + this.random8String();
        try {
            final User user = this.createUser(userName);
            try {
                this.createStack(stackName,
                        "showcase.yaml",
                        new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                        new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                        new Parameter().withParameterKey("OS").withParameterValue("Ubuntu")
                );
                final String host = this.getStackOutputValue(stackName, "PublicName");
                this.probeSSH(host, user);
            } finally {
                this.deleteStack(stackName);
            }
        } finally {
            this.deleteUser(userName);
        }
    }

    @Test
    public void testDefaultAmazonLinux() throws Exception {
        final String stackName = "showcase-" + this.random8String();
        final String userName = "user-" + this.random8String();
        try {
            final User user = this.createUser(userName);
            try {
                this.createStack(stackName,
                        "showcase.yaml",
                        new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                        new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId())
                );
                final String host = this.getStackOutputValue(stackName, "PublicName");
                this.probeSSH(host, user);
            } finally {
                this.deleteStack(stackName);
            }
        } finally {
            this.deleteUser(userName);
        }
    }

}
