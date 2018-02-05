package de.widdix.awsec2ssh;

import com.amazonaws.services.cloudformation.model.Parameter;
import org.junit.Test;

public class TestShowcaseRPM extends ACloudFormationTest {

    // TODO make Version parameter configurable via ENV variable

    @Test
    public void testCentOS() throws Exception {
        final String stackName = "showcase-rpm-" + this.random8String();
        final String userName = "user-" + this.random8String();
        try {
            final User user = this.createUser(userName);
            try {
                if (Config.has(Config.Key.VERSION)) {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("OS").withParameterValue("CentOS"),
                            new Parameter().withParameterKey("Version").withParameterValue(Config.get(Config.Key.VERSION))
                    );
                } else {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("OS").withParameterValue("CentOS")
                    );
                }
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
    public void testRHEL() throws Exception {
        final String stackName = "showcase-rpm-" + this.random8String();
        final String userName = "user-" + this.random8String();
        try {
            final User user = this.createUser(userName);
            try {
                if (Config.has(Config.Key.VERSION)) {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("OS").withParameterValue("RHEL"),
                            new Parameter().withParameterKey("Version").withParameterValue(Config.get(Config.Key.VERSION))
                    );
                } else {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("OS").withParameterValue("RHEL")
                    );
                }
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
    public void testSUSELinuxEnterpriseServer() throws Exception {
        final String stackName = "showcase-rpm-" + this.random8String();
        final String userName = "user-" + this.random8String();
        try {
            final User user = this.createUser(userName);
            try {
                if (Config.has(Config.Key.VERSION)) {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("OS").withParameterValue("SUSELinuxEnterpriseServer"),
                            new Parameter().withParameterKey("Version").withParameterValue(Config.get(Config.Key.VERSION))
                    );
                } else {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("OS").withParameterValue("SUSELinuxEnterpriseServer")
                    );
                }
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
    public void testAmazonLinux2() throws Exception {
        final String stackName = "showcase-rpm-" + this.random8String();
        final String userName = "user-" + this.random8String();
        try {
            final User user = this.createUser(userName);
            try {
                if (Config.has(Config.Key.VERSION)) {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("OS").withParameterValue("AmazonLinux2"),
                            new Parameter().withParameterKey("Version").withParameterValue(Config.get(Config.Key.VERSION))
                    );
                } else {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("OS").withParameterValue("AmazonLinux2")
                    );
                }
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
        final String stackName = "showcase-rpm-" + this.random8String();
        final String userName = "user-" + this.random8String();
        try {
            final User user = this.createUser(userName);
            try {
                if (Config.has(Config.Key.VERSION)) {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId()),
                            new Parameter().withParameterKey("Version").withParameterValue(Config.get(Config.Key.VERSION))
                    );
                } else {
                    this.createStack(stackName,
                            "showcase-rpm.yaml",
                            new Parameter().withParameterKey("VPC").withParameterValue(this.getDefaultVPC().getVpcId()),
                            new Parameter().withParameterKey("Subnet").withParameterValue(this.getDefaultSubnets().get(0).getSubnetId())
                    );
                }
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
