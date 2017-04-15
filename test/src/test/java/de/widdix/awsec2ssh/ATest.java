package de.widdix.awsec2ssh;

import com.evanlennick.retry4j.CallExecutor;
import com.evanlennick.retry4j.CallResults;
import com.evanlennick.retry4j.RetryConfig;
import com.evanlennick.retry4j.RetryConfigBuilder;
import com.jcraft.jsch.JSch;
import com.jcraft.jsch.Session;
import org.junit.Assert;

import java.time.temporal.ChronoUnit;
import java.util.concurrent.Callable;

public abstract class ATest {

    protected final <T> T retry(Callable<T> callable) {
        final Callable<T> wrapper = () -> {
            try {
                return callable.call();
            } catch (final Exception e) {
                System.out.println("retry[] exception: " + e.getMessage());
                e.printStackTrace();
                throw e;
            }
        };
        final RetryConfig config = new RetryConfigBuilder()
                .retryOnAnyException()
                .withMaxNumberOfTries(30)
                .withDelayBetweenTries(10, ChronoUnit.SECONDS)
                .withFixedBackoff()
                .build();
        final CallResults<Object> results = new CallExecutor(config).execute(wrapper);
        return (T) results.getResult();
    }

    protected final void probeSSH(final String host, final AAWSTest.User user) {
        final Callable<Boolean> callable = () -> {
            final JSch jsch = new JSch();
            final Session session = jsch.getSession(user.userName, host);
            jsch.addIdentity(user.userName, user.sshPrivateKeyBlob, null, null);
            jsch.setConfig("StrictHostKeyChecking", "no"); // for testing this should be fine. adding the host key seems to be only possible via a file which is not very useful here
            session.connect(10000);
            session.disconnect();
            return true;
        };
        Assert.assertTrue(this.retry(callable));
    }

}
