/**
 * Copyright (C) 2010 imedias
 *
 * This file is part of JBackpack.
 *
 * JBackpack is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation; either version 3 of the License, or (at your option) any
 * later version.
 *
 * JBackpack is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package ch.fhnw.util;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.text.MessageFormat;
import java.text.NumberFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.ResourceBundle;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.swing.JProgressBar;

/**
 * some file tools
 * @author Ronny Standtke <ronny.standtke@fhnw.ch>
 */
public class FileTools {

    private static final Logger LOGGER =
            Logger.getLogger(FileTools.class.getName());
    private final static ResourceBundle BUNDLE = ResourceBundle.getBundle(
            "ch/fhnw/jbackpack/Strings");
    private static final String LINE_SEPARATOR =
            System.getProperty("line.separator");
    private final static NumberFormat NUMBER_FORMAT =
            NumberFormat.getInstance();
    private static final long UNKNOWN_SPACE = 1073741824000L;
    public static final String unitWinCaps = "N:\\";
    public static final String unitWin = "n:\\"; //File.separatorChar
    public static final char separatorChar = File.separatorChar;
    public static final String separator = File.separator;
    public static final int SSHFS = 2;
    public static final int SMBFS = 1;
    public static long mountWaitTime = 30000;
    public static long mountStep = 1000;
    public static String USER_HOME = System.getProperty("user.home");
    public static String TEMP_DIR = System.getProperty("java.io.tmpdir");
    public static boolean DO_VSS = (CurrentOperatingSystem.OS == OperatingSystem.Windows);
    public static String mapdrive = "m:";
    public static final String rdiffbackupCommand = (CurrentOperatingSystem.OS == OperatingSystem.Windows) ? USER_HOME+"\\.jbackpack\\rdiff-backup.exe" : "rdiff-backup";

    /**
     * checks if a directory is writable
     * @param directory the directory to check
     * @return <code>true</code>, if the directory is writable,
     * <code>false</code> otherwise
     */
    public static boolean canWrite(File directory) {
        // TODO: just checking testFile.canWrite() fails on Windows, see
        // http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=4420020
        // Therefore we create a temporary file instead of calling canWrite().
        try {
            File tmpFile = File.createTempFile("test", null, directory);
            if (!tmpFile.delete()) {
                LOGGER.log(Level.WARNING, "could not delete {0}", tmpFile);
            }
            return true;
        } catch (IOException ex) {
            LOGGER.log(Level.WARNING, directory + " is not writable", ex);
            return false;
        }
    }

    /**
     * mounts an SMB share on Windows
     * @param host the host
     * @param share the share
     * @param user the user
     * @param password the password
     * @return the return value of the mount operation
     * @throws IOException if an I/O exception occurs
     */
    public static int mountSmbWindows(String host, String share,
            String user, String password) throws IOException {

        List<String> commandList = new ArrayList<String>();
        commandList.add("net");
        commandList.add("use");
        commandList.add("*");
        commandList.add("\\\\" + host + "\\" + share);
        if ((user != null) && !user.isEmpty()) {
            commandList.add("/USER:" + user);
        }
        if ((password != null) && !password.isEmpty()) {
            commandList.add(password);
        }
        String[] commandArray = commandList.toArray(
                new String[commandList.size()]);

        // set level to OFF to prevent password leaking into logfiles
        Logger logger = Logger.getLogger(ProcessExecutor.class.getName());
        Level level = logger.getLevel();
        logger.setLevel(Level.OFF);

        ProcessExecutor processExecutor = new ProcessExecutor();
        int returnValue = processExecutor.executeProcess(commandArray);

        // restore previous log level
        logger.setLevel(level);

        return returnValue;
    }

    /**
     * mounts an SMB share on Linux
     * @param host the host
     * @param share the share
     * @param user the user
     * @param smbPassword the SMB password
     * @param sudoPassword the local sudo password
     * @return the return value of the mount operation
     * @throws IOException if an I/O exception occurs
     */
    public static int mountSmbLinux(String host, String share,
            String user, String smbPassword, String sudoPassword)
            throws IOException {
        String mountPoint = createMountPoint(
                new File(System.getProperty("user.home")), host).getPath();
        StringBuilder stringBuilder = new StringBuilder(
                "#!/bin/sh" + LINE_SEPARATOR
                + "UID=$(id -u)" + LINE_SEPARATOR
                + "GID=$(id -g)" + LINE_SEPARATOR
                + "echo " + sudoPassword + " | "
                + "sudo -S mount -t smbfs -o ");
        boolean optionSet = false;
        if ((user != null) && !user.isEmpty()) {
            stringBuilder.append("username=");
            stringBuilder.append(user);
            optionSet = true;
        }
        if ((smbPassword != null) && !smbPassword.isEmpty()) {
            if (optionSet) {
                stringBuilder.append(',');
                optionSet = true;
            }
            stringBuilder.append("password=");
            stringBuilder.append(smbPassword);
        }
        if (optionSet) {
            stringBuilder.append(',');
        }
        stringBuilder.append("uid=${UID},gid=${GID} //");
        stringBuilder.append(host);
        stringBuilder.append('/');
        stringBuilder.append(share);
        stringBuilder.append(' ');
        stringBuilder.append(mountPoint);

        // set level to OFF to prevent password leaking into logfiles
        Logger logger = Logger.getLogger(ProcessExecutor.class.getName());
        Level level = logger.getLevel();
        logger.setLevel(Level.OFF);

        ProcessExecutor processExecutor = new ProcessExecutor();
        int returnValue = processExecutor.executeScript(
                stringBuilder.toString());

        // restore previous log level
        logger.setLevel(level);

        return returnValue;
    }

    /**
     * mounts an SMB share on Mac OS X
     * @param host the host
     * @param share the share
     * @param user the user
     * @param smbPassword the SMB password
     * @return the return value of the mount operation
     * @throws IOException if an I/O exception occurs
     */
    public static int mountSmbMacOSX(String host, String share,
            String user, String smbPassword)
            throws IOException {
        String mountPoint = createMountPoint(
                new File(System.getProperty("user.home")), host).getPath();
        StringBuilder stringBuilder = new StringBuilder();
        stringBuilder.append("//");
        if ((user != null) && !user.isEmpty()) {
            stringBuilder.append(user);
            if ((smbPassword != null) && !smbPassword.isEmpty()) {
                stringBuilder.append(':');
                stringBuilder.append(smbPassword);
            }
            stringBuilder.append('@');
        }
        stringBuilder.append(host);
        stringBuilder.append('/');
        stringBuilder.append(share);

        // set level to OFF to prevent password leaking into logfiles
        Logger logger = Logger.getLogger(ProcessExecutor.class.getName());
        Level level = logger.getLevel();
        logger.setLevel(Level.OFF);

        ProcessExecutor processExecutor = new ProcessExecutor();
        int returnValue = processExecutor.executeProcess("mount", "-t", "smbfs",
                stringBuilder.toString(), mountPoint);

        // restore previous log level
        logger.setLevel(level);

        return returnValue;
    }

    /**
     * checks if a directory is a subdirectory of another directory
     * @param superDir the super directory
     * @param subDir the sub directory
     * @return <code>true</code>, if <code>subDir</code> is a subdirectory of
     * <code>superDir</code>, <code>false</code> otherwise
     * @throws IOException if an I/O exception occurs
     */
    public static boolean isSubDir(File superDir, File subDir)
            throws IOException {
        File canonicalSuper = superDir.getCanonicalFile();
        File canonicalSub = subDir.getCanonicalFile();
        boolean isSubDir = canonicalSuper.equals(canonicalSub);
        while ((canonicalSub != null) && !isSubDir) {
            canonicalSub = canonicalSub.getParentFile();
            isSubDir = canonicalSuper.equals(canonicalSub);
        }
        return isSubDir;
    }

    /**
     * shows space information about a given file on a progressbar
     * @param file a given file
     * @param progressBar the progressbar where to display the space information
     * about the given file
     */
    public static void showSpaceInfo(File file, JProgressBar progressBar) {
        if (isSpaceKnown(file)) {
            long totalSpace = file.getTotalSpace();
            if (totalSpace == 0) {
                progressBar.setValue(0);
                progressBar.setString("");
            } else {
                long usedSpace = totalSpace - file.getUsableSpace();
                progressBar.setValue((int) ((usedSpace * 100) / totalSpace));
                String usedSpaceString = getDataVolumeString(usedSpace, 1);
                String totalSpaceString = getDataVolumeString(totalSpace, 1);
                String text = BUNDLE.getString("Free_Space");
                text = MessageFormat.format(
                        text, usedSpaceString, totalSpaceString);
                progressBar.setString(text);
            }
        } else {
            progressBar.setValue(0);
            progressBar.setString(BUNDLE.getString("Unknown"));
        }
    }

    /**
     * recusively deletes a file
     * @param file the file to delete
     * @return <code>true</code> if and only if the file or directory is
     *          successfully deleted; <code>false</code> otherwise
     * @throws IOException if an I/O exception occurs
     */
    public static boolean recursiveDelete(File file) throws IOException {
        // do NOT(!) follow symlinks when deleting files
        if (file.isDirectory() && !isSymlink(file)) {
            File[] subFiles = file.listFiles();
            if (subFiles != null) {
                for (File subFile : subFiles) {
                    recursiveDelete(subFile);
                }
            }
        }
        return file.delete();
    }

    /**
     * returns the string representation of a given data volume
     * @param bytes the datavolume given in Byte
     * @param fractionDigits the number of fraction digits to display
     * @return the string representation of a given data volume
     */
    public static String getDataVolumeString(long bytes, int fractionDigits) {
        if (bytes >= 1024) {
            NUMBER_FORMAT.setMaximumFractionDigits(fractionDigits);
            float kbytes = (float) bytes / 1024;
            if (kbytes >= 1024) {
                float mbytes = (float) bytes / 1048576;
                if (mbytes >= 1024) {
                    float gbytes = (float) bytes / 1073741824;
                    if (gbytes >= 1024) {
                        float tbytes = (float) bytes / 1099511627776L;
                        return NUMBER_FORMAT.format(tbytes) + " TiB";
                    }
                    return NUMBER_FORMAT.format(gbytes) + " GiB";
                }

                return NUMBER_FORMAT.format(mbytes) + " MiB";
            }

            return NUMBER_FORMAT.format(kbytes) + " KiB";
        }

        return NUMBER_FORMAT.format(bytes) + " Byte";
    }

    /**
     * checks, if space information is available for a given file
     * @param file the file to check
     * @return <tt>true</tt>, if space information is available,
     * <tt>false</tt> otherwise
     */
    public static boolean isSpaceKnown(File file) {
        long usableSpace = file.getUsableSpace();
        long totalSpace = file.getTotalSpace();
        return (usableSpace != UNKNOWN_SPACE
                || totalSpace != UNKNOWN_SPACE);
    }

    /**
     * checks if a file is a symlink
     * @param file the file to check
     * @return <tt>true</tt>, if <tt>file</tt> is a symlink, <tt>false</tt>
     * otherwise
     * @throws IOException if an I/O exception occurs
     */
    public static boolean isSymlink(File file) throws IOException {
        File canon;
        if (file.getParent() == null) {
            canon = file;
        } else {
            File canonDir = file.getParentFile().getCanonicalFile();
            canon = new File(canonDir, file.getName());
        }
        return !canon.getCanonicalFile().equals(canon.getAbsoluteFile());
    }

    /**
     * returns the encfs mount point of a given search string or <tt>null</tt>,
     * if the mount point can not be determined
     * @param searchString a string that the encfs mountpoint must contain
     * @return the mount point of a device or <tt>null</tt>, if the mount point
     * can not be determined
     * @throws IOException if reading /proc/mounts fails
     */
    public static String getEncfsMountPoint(String searchString)
            throws IOException {
        switch (CurrentOperatingSystem.OS) {
//        	case Windows:
//        		break:
            case Linux:
                List<String> mounts = readFile(new File("/proc/mounts"));
                for (String mount : mounts) {
                    String[] tokens = mount.split(" ");
                    if (tokens[0].equals("encfs")
                            && tokens[1].contains(searchString)) {
                        return tokens[1];
                    }
                }
                break;

            case Mac_OS_X:
                ProcessExecutor processExecutor = new ProcessExecutor();
                processExecutor.executeProcess(true, true, "mount");
                mounts = processExecutor.getStdOutList();
                for (String mount : mounts) {
                    String[] tokens = mount.split(" ");
                    if (tokens[0].startsWith("encfs@fuse")
                            && tokens[2].contains(searchString)) {
                        return tokens[2];
                    }
                }
                break;

            default:
                LOGGER.log(Level.WARNING,
                        "{0} is not supported", CurrentOperatingSystem.OS);

        }
        return null;
    }

    /**
     * umounts via sudo
     * @param mountPoint the mountpoint to umount
     * @param sudoPassword the sudo password
     * @return the return value of the umount operation
     * @throws IOException
     */
    public static boolean umountSudo(String mountPoint, String sudoPassword)
            throws IOException {

        String umountScript = "#!/bin/sh" + LINE_SEPARATOR
                + "echo " + sudoPassword + " | sudo -S umount " + mountPoint;

        // set level to OFF to prevent password leaking into logfiles
        Logger logger = Logger.getLogger(ProcessExecutor.class.getName());
        Level level = logger.getLevel();
        logger.setLevel(Level.OFF);

        ProcessExecutor processExecutor = new ProcessExecutor();
        int returnValue = processExecutor.executeScript(umountScript);

        // restore previous log level
        logger.setLevel(level);

        return (returnValue == 0);
    }

    /**
     * umounts a drive on Windows
     * @param drive the drive letter and the colons, e.g. "Z:"
     * @return the return value of the "net use &lt;drive letter&gt; /delete command
     * @throws IOException
     */
    public static boolean umountWin(String drive) throws IOException {
        // set level to OFF to prevent password leaking into logfiles
        Logger logger = Logger.getLogger(ProcessExecutor.class.getName());
        Level level = logger.getLevel();
        logger.setLevel(Level.OFF);

        ProcessExecutor processExecutor = new ProcessExecutor();
        int returnValue = processExecutor.executeProcess(
                "net", "use", drive, "/delete");

        // restore previous log level
        logger.setLevel(level);

        return (returnValue == 0);
    }

    /**
     * umounts a FUSE filesystem
     * @param mountPoint the mountpoint to umount
     * @param delete if <tt>true</tt>, the mountpoint will be deleted if it is
     * empty
     * @return <tt>true</tt>, if umounting succeeded, <tt>false</tt> otherwise
     */
    public static boolean umountFUSE(File mountPoint, boolean delete) {
        ProcessExecutor processExecutor = new ProcessExecutor();
        switch (CurrentOperatingSystem.OS) {
        	case Windows:
               int returnValue = processExecutor.executeProcess(
                        USER_HOME+"\\.jbackpack\\dokanctl.exe", "/u", unitWin.substring(0, 1));
                boolean success = (returnValue == 0);
                if (!success) {
                    LOGGER.log(Level.WARNING,
                            "could not umount {0}", mountPoint);
                }
                return true; //bug: dokanctl returns 1
        	case Linux:
                returnValue = processExecutor.executeProcess(
                        "fusermount", "-u", mountPoint.getPath());
                success = (returnValue == 0);
                if (!success) {
                    LOGGER.log(Level.WARNING,
                            "could not umount {0}", mountPoint);
                }
                if (delete) {
                    deleteIfEmpty(mountPoint);
                }
                return success;

            case Mac_OS_X:
                returnValue = processExecutor.executeProcess(
                        "umount", mountPoint.getPath());
                success = (returnValue == 0);
                if (!success) {
                    LOGGER.log(Level.WARNING,
                            "could not umount {0}", mountPoint);
                }
                if (delete) {
                    deleteIfEmpty(mountPoint);
                }
                return success;

            default:
                LOGGER.log(Level.WARNING,
                        "{0} is not supported", CurrentOperatingSystem.OS);
                return false;
        }
    }

    /**
     * umounts selector
     * @param mountPoint the mountpoint or unit to umount
     * @param delete if <tt>true</tt>, the mountpoint will be deleted if it is
     * empty
     * @param type 1 sshfs, 2 smbfs
     * @return <tt>true</tt>, if umounting succeeded, <tt>false</tt> otherwise
     */
    public static boolean umount(String mountPoint,int type,String password,boolean delete,ProcessExecutor oldExecutor) {
        ProcessExecutor processExecutor = new ProcessExecutor();
        int returnValue = -1;
        boolean success = false;

        switch (CurrentOperatingSystem.OS) {
        	case Windows:
        	   if (type == SMBFS) returnValue = processExecutor.executeProcess(
                       "net", "use", mountPoint, "/delete");
        	   else if (type == SSHFS){
        		   returnValue = processExecutor.executeProcess(
                        USER_HOME+"\\.jbackpack\\dokanctl.exe", "/u", unitWin.substring(0, 1));
        		   if (oldExecutor != null) oldExecutor.destroy();
        	   }
                success = (returnValue == 0);
                if (!success) {
                    LOGGER.log(Level.WARNING,
                            "could not umount {0}", mountPoint);
                }
                success= true; //bug: dokanctl returns 1
                break;
        	case Linux:
        		if (type == SMBFS) {
        			boolean errorS=false;
        	        String umountScript = "#!/bin/sh" + LINE_SEPARATOR
        	                + "echo " + password + " | sudo -S umount " + mountPoint;

        	        // set level to OFF to prevent password leaking into logfiles
        	        Logger logger = Logger.getLogger(ProcessExecutor.class.getName());
        	        Level level = logger.getLevel();
        	        logger.setLevel(Level.OFF);
        			try{
        				processExecutor.executeScript(umountScript);

        			}catch(IOException ex){
        				errorS=true;
        			}
    		        // restore previous log level
    		        logger.setLevel(level);
    		        if (errorS)                        LOGGER.log(Level.WARNING,
                            "Linux SMB (using sudo) could not umount {0}", mountPoint);
        		}
        		else if (type == SSHFS) returnValue = processExecutor.executeProcess(
                        "fusermount", "-u", mountPoint);
                success = (returnValue == 0);
                if (!success) {
                    LOGGER.log(Level.WARNING,
                            "could not umount {0}", mountPoint);
                }
                if (delete) {
                    deleteIfEmpty(new File(mountPoint));
                }
                break;

            case Mac_OS_X:
                returnValue = processExecutor.executeProcess(
                        "umount", mountPoint);
                success = (returnValue == 0);
                if (!success) {
                    LOGGER.log(Level.WARNING,
                            "could not umount {0}", mountPoint);
                }
                if (delete) {
                    deleteIfEmpty(new File(mountPoint));
                }
                break;

            default:
                LOGGER.log(Level.WARNING,
                        "{0} is not supported", CurrentOperatingSystem.OS);
                success= false;
        }

        return success;
    }

    /**
     * deletes a directory when it is empty
     * @param directory the directory
     * @return <tt>true</tt> if the directory was deleted, <tt>false</tt>
     * otherwise
     */
    public static boolean deleteIfEmpty(File directory) {
        if (directory.listFiles().length == 0) {
            if (!directory.delete()) {
                LOGGER.log(Level.WARNING,
                        "could not delete {0}", directory);
                return false;
            }
        } else {
            LOGGER.log(Level.WARNING,
                    "encfs mountpoint {0} is not empty", directory);
            return false;
        }
        return true;
    }

    /**
     * mounts an encrypted filesystem
     * @param cipherDir the directory where only ciphertext is visible
     * @param plainDir the directory where plaintext is visible
     * @param password the encryption password
     * @return <tt>true</tt> if mounting was successfull,
     * <tt>false</tt> otherwise
     * @throws IOException
     */
    public static boolean mountEncFs(String cipherDir, String plainDir,
            String password) throws IOException {
    	int returnValue;
        String script = "#!/bin/sh" + LINE_SEPARATOR
                + "echo \"" + password + "\" | encfs -S \"" + cipherDir
                + "\" \"" + plainDir + '\"' + LINE_SEPARATOR;

        ProcessExecutor processExecutor = new ProcessExecutor();

        // set level to OFF to prevent password leaking into logfiles
        Logger logger = Logger.getLogger(ProcessExecutor.class.getName());
        Level level = logger.getLevel();
        logger.setLevel(Level.OFF);

        if ((CurrentOperatingSystem.OS != OperatingSystem.Windows)) returnValue = processExecutor.executeScript(script);
        else returnValue = processExecutor.executeProcess(true,true,USER_HOME+"\\.jbackpack\\enfs.exe",cipherDir,plainDir );
        // restore previous log level
        logger.setLevel(level);

        if (returnValue == 0) {
            return true;
        }
        if (LOGGER.isLoggable(Level.WARNING)) {
            LOGGER.log(Level.WARNING, "could not mount {0} to {1}",
                    new Object[]{cipherDir, plainDir});
        }
        return false;
    }

    /**
     * checks if a given directory is encrypted with encfs
     * @param directory the directory to check
     * @return <tt>true</tt>, if a given directory is encrypted with encfs,
     * <tt>false</tt> otherwise
     */
    public static boolean isEncFS(String directory) {
        ProcessExecutor processExecutor = new ProcessExecutor();
        int returnValue;
        if ((CurrentOperatingSystem.OS != OperatingSystem.Windows)) returnValue = processExecutor.executeProcess("encfsctl", directory);
        else returnValue = processExecutor.executeProcess(USER_HOME+"\\.jbackpack\\encfsctl.exe", directory);
        return returnValue == 0;
    }

    /**
     * reads a file line by line
     * @param file the file to read
     * @return the list of lines in this file
     * @throws IOException if an I/O exception occurs
     */
    public static List<String> readFile(File file) throws IOException {
        List<String> lines = new ArrayList<String>();
        BufferedReader reader = new BufferedReader(new FileReader(file));
        for (String line = reader.readLine(); line != null;) {
            lines.add(line);
            line = reader.readLine();
        }
        reader.close();
        return lines;
    }

    /**
     * creates a temporary directory
     * @param prefix the directory prefix
     * @param suffix the directory suffix
     * @return a temporary directory
     * @throws IOException if an I/O exception occurs
     */
    public static File createTempDirectory(String prefix, String suffix)
            throws IOException {
        File tempDirectory = File.createTempFile(prefix, suffix);
        tempDirectory.delete();
        if (tempDirectory.mkdirs()) {
            LOGGER.log(Level.INFO,
                    "using temporary directory {0}", tempDirectory);
            return tempDirectory;
        } else {
            throw new IOException("could not create " + tempDirectory);
        }
    }

    /**
     * creates a temporary directory
     * @param parentDir the parent directory
     * @param name the name of the temporary directory
     * @return the temporary directory
     */
    public static File createTempDirectory(File parentDir, String name) {
        File tempDir = new File(parentDir, name);
        if (tempDir.exists()) {
            // search for an alternative non-existing directory
            for (int i = 1;
                    (tempDir = new File(parentDir, name + i)).exists(); i++) {
            }
        }
        if (!tempDir.mkdirs()) {
            LOGGER.log(Level.WARNING, "can not create {0}", tempDir);
        }
        return tempDir;
    }

    /**
     * creates a usable mountpoint in a given directory with a preferred name
     * @param directory the parent directory of the mountpoint
     * @param name the preferred name of the mountpoint
     * @return a usable mountpoint in a given directory
     * @throws IOException if an I/O exception occurs
     */
    public static File createMountPoint(File directory, String name)
            throws IOException {
        File mountPoint = new File(directory, name);
        if (mountPoint.exists()) {
            if (isMountPoint(mountPoint.getPath())
                    || mountPoint.listFiles().length != 0) {
                // we can not use the preferred name
                // lets find an alternative
                for (int i = 1;; i++) {
                    mountPoint = new File(directory, name + "_" + i);
                    if (mountPoint.exists()) {
                        if (!isMountPoint(mountPoint.getPath())
                                && mountPoint.listFiles().length == 0) {
                            // we re-use an existing directory
                            return mountPoint;
                        }
                    } else {
                        if (mountPoint.mkdirs()) {
                            return mountPoint;
                        } else {
                            LOGGER.log(Level.WARNING,
                                    "can not create {0}", mountPoint);
                        }
                    }
                }
            } else {
                // we re-use an existing directory
                return mountPoint;
            }
        } else {
            if (mountPoint.mkdirs()) {
                return mountPoint;
            } else {
                LOGGER.log(Level.WARNING, "can not create {0}", mountPoint);
            }
        }
        return null;
    }

    /**
     * returns <code>true</code> if a given path is a currently used mountpoint,
     * <code>false</code> othwerwise
     * @param path the path to check
     * @return <code>true</code> if a given path is a currently used mountpoint,
     * <code>false</code> othwerwise
     * @throws IOException if an I/O exception occurs
     */
    public static boolean isMountPoint(String path) throws IOException {

        switch (CurrentOperatingSystem.OS) {
        	case Windows:
        		if (path == "n") return true;
                LOGGER.log(Level.FINEST,"mountpoint:",path);
        		break;
            case Linux:
                List<String> mounts = readFile(new File("/proc/mounts"));
                for (String mount : mounts) {
                    String[] tokens = mount.split(" ");
                    if (tokens[1].equals(path)) {
                        return true;
                    }
                }
                break;

            case Mac_OS_X:
                ProcessExecutor processExecutor = new ProcessExecutor();
                processExecutor.executeProcess(true, true, "mount");
                mounts = processExecutor.getStdOutList();
                for (String mount : mounts) {
                    String[] tokens = mount.split(" ");
                    if (tokens[2].equals(path)) {
                        return true;
                    }
                }
                break;

            default:
                LOGGER.log(Level.WARNING,
                        "{0} is not supported", CurrentOperatingSystem.OS);
        }
        return false;
    }

    /**
     * returns the mount point of a device or <tt>null</tt>, if the mount point
     * can not be determined
     * @param device the device to search for
     * @return the mount point of a device or <tt>null</tt>, if the mount point
     * can not be determined
     * @throws IOException if an I/O exception occurs
     */
    public static String getMountPoint(String device) throws IOException {
        switch (CurrentOperatingSystem.OS) {
            case Linux:
                List<String> mounts = readFile(new File("/proc/mounts"));
                for (String mount : mounts) {
                    String[] tokens = mount.split(" ");
                    if (tokens[0].startsWith(device)) {
                        return tokens[1];
                    }
                }
                break;

            case Mac_OS_X:
                ProcessExecutor processExecutor = new ProcessExecutor();
                processExecutor.executeProcess(true, true, "mount");
                mounts = processExecutor.getStdOutList();
                for (String mount : mounts) {
                    String[] tokens = mount.split(" ");
                    if (tokens[0].startsWith(device)) {
                        return tokens[2];
                    }
                }
                break;

            case Windows:
                processExecutor = new ProcessExecutor();
                processExecutor.executeProcess(true, true, "net", "use");
                mounts = processExecutor.getStdOutList();
                // output lines look like this:
                //      <drive letter>:    \\<host>\<share>       <description>
                Pattern pattern = Pattern.compile(".*(\\S:).*"
                        + Pattern.quote(device.toLowerCase()) + ".*");
                for (String mount : mounts) {
                    Matcher matcher = pattern.matcher(mount.toLowerCase());
                    if (matcher.matches()) {
                        return matcher.group(1);
                    }
                }
                break;

            default:
                LOGGER.log(Level.WARNING,
                        "{0} is not supported", CurrentOperatingSystem.OS);
        }
        return null;
    }

    /**
     * checks, if a certain device is mounted
     * @param device the device to check
     * @return <tt>true</tt> if the device is mounted, <tt>false</tt> otherwise
     * @throws IOException if an I/O exception occurs
     */
    public static boolean isMounted(String device) throws IOException {
        return getMountPoint(device) != null;
    }

    /**
     * Change password,
     * @param rawBackupDestination dir destination
     * @param oldPassword the encryption password
     * @param newPassword the encryption password
     * @return <tt>true</tt> if mounting was successfull,
     * <tt>false</tt> otherwise
     */
    public static int changePassword(String oldPassword, String newPassword,
            String rawBackupDestination) {
        String changePasswordScript =
                "#!/usr/bin/expect -f" + LINE_SEPARATOR
                + "set oldPassword [lindex $argv 0]" + LINE_SEPARATOR
                + "set newPassword [lindex $argv 1]" + LINE_SEPARATOR
                + "spawn encfsctl passwd \""
                + rawBackupDestination + '\"' + LINE_SEPARATOR
                + "expect \"EncFS Password: \"" + LINE_SEPARATOR
                + "send \"$oldPassword\r\"" + LINE_SEPARATOR
                + "expect \"New Encfs Password: \"" + LINE_SEPARATOR
                + "send \"$newPassword\r\"" + LINE_SEPARATOR
                + "expect \"Verify Encfs Password: \"" + LINE_SEPARATOR
                + "send \"$newPassword\r\"" + LINE_SEPARATOR
                + "expect eof" + LINE_SEPARATOR
                + "set ret [lindex [wait] 3]" + LINE_SEPARATOR
                + "puts \"return value: $ret\"" + LINE_SEPARATOR
                + "exit $ret";

        if ((CurrentOperatingSystem.OS != OperatingSystem.Windows)) return -1;

        // set level to OFF to prevent password leaking into logfiles
        Logger logger = Logger.getLogger(ProcessExecutor.class.getName());
        Level level = logger.getLevel();
        logger.setLevel(Level.OFF);

        int returnValue = -1;
        ProcessExecutor processExecutor = new ProcessExecutor();
        try {
            returnValue = processExecutor.executeScript(
                    changePasswordScript, oldPassword, newPassword);
        } catch (IOException ex) {
            LOGGER.log(Level.SEVERE, null, ex);
        }

        // restore previous log level
        logger.setLevel(level);

        return returnValue;
    }
    /**
     * Change createEncTempDirectory,
     * @param rawBackupDestination dir destination
     * @param oldPassword the encryption password
     * @param newPassword the encryption password
     * @return <tt>true</tt> if mounting was successfull,
     * <tt>false</tt> otherwise
     */
    public static void createEncTempDirectory (String password,String tmpCipherPath, String tmpEncfsMountPoint){

    	ProcessExecutor processExecutor = new ProcessExecutor();
    	try {
    		if ((CurrentOperatingSystem.OS != OperatingSystem.Windows))
    		{
		        File passwordScript = processExecutor.createScript(
		                "#!/bin/sh" + LINE_SEPARATOR
		                + "echo \"" + password + '"');
		        String passwordScriptPath = passwordScript.getPath();
		        String setupScript = "#!/bin/sh" + LINE_SEPARATOR
		                + "echo \"\" | encfs --extpass=" + passwordScriptPath
		                + " \"" + tmpCipherPath + "\" " + tmpEncfsMountPoint;
		        // the return value of the script is of no use...
		        processExecutor.executeScript(setupScript);

		        if (!passwordScript.delete()) {
		            LOGGER.log(Level.WARNING,
		                    "could not delete {0}", passwordScript);
		        }
    		}else{
    			processExecutor.executeProcess(true,true,USER_HOME+"/jpackpack/encfs.exe",tmpCipherPath,tmpEncfsMountPoint);
    		}
        } catch (IOException ex) {
            LOGGER.log(Level.SEVERE, null, ex);
        }
    }
    /**
     * Change mountSSHFS,
     * @param rawBackupDestination dir destination
     * @param oldPassword the encryption password
     * @param newPassword the encryption password
     * @return <tt>true</tt> if mounting was successfull,
     * <tt>false</tt> otherwise
     */
    public static boolean mountSSHFS (ProcessExecutor processExecutor,String user,String host,String baseDir, String mountName, String identity)
    		 throws IOException {

    	String userHostDir = user + "@" + host + ':';
    	String mountPoint;
    	if (CurrentOperatingSystem.OS != OperatingSystem.Windows)
    		mountPoint = createMountPoint(new File(mountName), host).getPath();
    	else mountPoint = unitWin;
    	int returnValue;
        if (!baseDir.isEmpty()) {
            if (!baseDir.startsWith("/")) {
                userHostDir += '/';
            }
            userHostDir += baseDir;
        }
    	if (identity == null)
    	{
    		if ((CurrentOperatingSystem.OS != OperatingSystem.Windows))
    		{
    			// collect output for error reporting

		        returnValue = processExecutor.executeProcess(true,
		                true, "sshfs", "-o", "ServerAliveInterval=15",
		                "-o", "workaround=rename,idmap=user",
		                userHostDir, mountPoint);
		        return (returnValue == 0);
    		}else{
            	// Modify to run in windows
            	// umount: dokanctl.exe /u DriveLetter
		        returnValue = processExecutor.executeNProcess(true,
		                true, USER_HOME+"\\.jbackpack\\DokanSSHFS.exe", // "-d",mountPoint,
		                "-i",USER_HOME+"\\.jbackpack\\"+host+".ppk", userHostDir);
		        for (long i=mountWaitTime;i>0;i=i-mountStep){
	    			if (!(new File(unitWin)).exists()){
						try {
							Thread.sleep(mountStep);
						} catch (InterruptedException e) {
							// TODO Auto-generated catch block
							e.printStackTrace();
						}
	    			}
		        }
    			if (!(new File(unitWin)).exists()){
    				//TEst if exist drive and processExecutor.destroy();
    				umount(mountPoint, FileTools.SSHFS, "",true,processExecutor);
    				returnValue=1;
    			}

		        return (returnValue == 0);
    		}
    	}
    	else
    	{
            // set level to OFF to prevent password leaking into
            // logfiles
            Logger logger = Logger.getLogger(
                    ProcessExecutor.class.getName());
            Level level = logger.getLevel();
            logger.setLevel(Level.OFF);
            //logger.info("sshMount:"+mountPoint);
    		if ((CurrentOperatingSystem.OS != OperatingSystem.Windows))
    		{
            	String loginScript = "#!/usr/bin/expect -f" + LINE_SEPARATOR
                    + "set password [lindex $argv 0]" + LINE_SEPARATOR
                    + "spawn -ignore HUP sshfs -o "
                    //+ "sshfs -o "
                    + "workaround=rename,idmap=user "
                    + userHostDir + " " + mountPoint + LINE_SEPARATOR
                    + "while 1 {" + LINE_SEPARATOR
                    + "    expect {" + LINE_SEPARATOR
                    + "        eof {" + LINE_SEPARATOR
                    + "            break" + LINE_SEPARATOR
                    + "        }" + LINE_SEPARATOR
                    + "        \"continue connecting*\" {"
                    + LINE_SEPARATOR
                    + "            send \"yes\r\"" + LINE_SEPARATOR
                    + "        }" + LINE_SEPARATOR
                    + "        \"password:\" {" + LINE_SEPARATOR
                    + "            send \"$password\r\""
                    + LINE_SEPARATOR
                    + "        }" + LINE_SEPARATOR
                    + "    }" + LINE_SEPARATOR
                    + "}" + LINE_SEPARATOR
                    + "set ret [lindex [wait] 3]" + LINE_SEPARATOR
                    + "puts \"return value: $ret\"" + LINE_SEPARATOR
                    + "exit $ret";
            	// TODO: the loginScript blocks when storing any output...
            	returnValue = processExecutor.executeScript(
                    loginScript, identity);
                // restore previous log level
                logger.setLevel(level);
    		}else {
    			returnValue = processExecutor.executeNProcess(false,false,USER_HOME+"\\.jbackpack\\DokanSSHFS.exe","-P",identity,userHostDir);
                // restore previous log level
                logger.setLevel(level);
                //ogger.log(Level.FINE, "DokeanSSHFS:"+USER_HOME+"\\jbackpack\\DokanSSHFS.exe"+"-P "+identity+" "+userHostDir);
		        for (long i=mountWaitTime;i>0;i=i-mountStep){
	    			if (!(new File(unitWin)).exists()){
						try {
							//logger.log(Level.FINE, "DokeanSSHFS:Return: {0}",returnValue);
							Thread.sleep(mountStep);
						} catch (InterruptedException e) {
							// TODO Auto-generated catch block
							e.printStackTrace();
						}
	    			}
		        }
    			if (!(new File(unitWin)).exists()){
    				//TEst if exist drive and processExecutor.destroy();
    				umount(mountPoint, FileTools.SSHFS, "",true,processExecutor);
    				returnValue=1;
    			}
    			logger.log(Level.FINE, "DokeanSSHFS:Return: {0}",returnValue);

    		}


            return (returnValue == 0);
    	}
    	//return true;

    }

    /**
     * Change testRdiffBackupServer,
     * @param rawBackupDestination dir destination
     * @param oldPassword the encryption password
     * @param newPassword the encryption password
     * @return <tt>true</tt> if mounting was successfull,
     * <tt>false</tt> otherwise
     */
	public static boolean testRdiffBackupServer (String user, String host,String password,byte WRONG_PASSWORD,ProcessExecutor processExecutor){
    	//in windows we use plink
		int returnValue = -1;
		if ((CurrentOperatingSystem.OS != OperatingSystem.Windows)){
        String checkScript = "#!/usr/bin/expect -f" + LINE_SEPARATOR
                + "set password [lindex $argv 0]" + LINE_SEPARATOR
                + "spawn -ignore HUP rdiff-backup --test-server "
                + user + '@' + host + "::/" + LINE_SEPARATOR
                + "while 1 {" + LINE_SEPARATOR
                + "    expect {" + LINE_SEPARATOR
                + "        eof {" + LINE_SEPARATOR
                + "            break" + LINE_SEPARATOR
                + "        }" + LINE_SEPARATOR
                + "        \"Permission denied*\" {" + LINE_SEPARATOR
                + "            exit " + WRONG_PASSWORD + LINE_SEPARATOR
                + "        }" + LINE_SEPARATOR
                + "        \"continue connecting*\" {" + LINE_SEPARATOR
                + "            send \"yes\r\"" + LINE_SEPARATOR
                + "        }" + LINE_SEPARATOR
                + "        \"" + user + '@' + host + "'s password:\" {"
                + LINE_SEPARATOR
                + "            send \"$password\r\"" + LINE_SEPARATOR
                + "        }" + LINE_SEPARATOR
                + "    }" + LINE_SEPARATOR
                + "}" + LINE_SEPARATOR
                + "set ret [lindex [wait] 3]" + LINE_SEPARATOR
                + "puts \"return value: $ret\"" + LINE_SEPARATOR
                + "exit $ret";

        // set level to OFF to prevent password leaking into
        // logfiles
        Logger logger = Logger.getLogger(
                ProcessExecutor.class.getName());
        Level level = logger.getLevel();
        logger.setLevel(Level.OFF);


        try {
            returnValue = processExecutor.executeScript(true, true,
                    checkScript, (password == null) ? "" : password);
        } catch (IOException ex) {
            LOGGER.log(Level.SEVERE, null, ex);
        }

        // restore previous log level
        logger.setLevel(level);
		}else{

	        try {
	        	if (password != null)
	        		returnValue = processExecutor.executeProcess(true, true,
	            		USER_HOME+"\\.jbackpack\\plink.exe", "-pw",password,user + '@' + host,
	            		"\"rdiff-backup --version\"");
	        	else
		            returnValue = processExecutor.executeProcess(true, true,
		            		USER_HOME+"\\.jbackpack\\plink.exe -i "+USER_HOME+"\\.jbackpack\\"+host+".ppk "+
		            		user + '@' + host + " \"rdiff-backup --version\"");


	        } catch (Exception ex1) {
	            LOGGER.log(Level.SEVERE, null, ex1);
	        }
			LOGGER.log(Level.FINEST, "Version of server rdiff: {0}", returnValue);
			//LOGGER.log(Level.INFO, "Version of server rdiff: {0}", password);

		}
        //wrongPassword = (WRONG_PASSWORD == returnValue);

        return (returnValue == 0);
	}

    /**
     * Change testselectedDirectory,
     * @param rawBackupDestination dir destination
     * @param oldPassword the encryption password
     * @param newPassword the encryption password
     * @return <tt>true</tt> if mounting was successfull,
     * <tt>false</tt> otherwise
     */
	public static boolean testSelectedDirectory (String selectedDirectory,ProcessExecutor processExecutor){
		if ((CurrentOperatingSystem.OS != OperatingSystem.Windows)){
			return processExecutor.executeProcess("rdiff-backup",
                "--check-destination-dir", selectedDirectory) == 0;
		}else{
			return processExecutor.executeProcess(USER_HOME+"\\.jbackpack\\rdiff-backup.exe",
	                "--check-destination-dir", selectedDirectory) ==0 ;
		}
	}

    /**
     * executes the given command
     * @param storeStdOut if <tt>true</tt>, the program stdout will be stored
     * in an internal list
     * @param storeStdErr if <tt>true</tt>, the program stderr will be stored
     * in an internal list
     * @param commandArray the command and parameters
     * @return the exit value of the command
     */
	public static int executeProcess (ProcessExecutor processExecutor,boolean storeStdOut, boolean storeStdErr,
            String... commandArray){
		return processExecutor.executeProcess(storeStdOut,storeStdErr,commandArray);
		/*
		if ((CurrentOperatingSystem.OS != OperatingSystem.Windows)){
			return processExecutor.executeProcess(storeStdOut,storeStdErr,commandArray);
		}else{
			commandArray[0] = USER_HOME+"\\jbackpack\\"+commandArray[0];
			return processExecutor.executeProcess(storeStdOut,storeStdErr,commandArray);

		}
		*/
	}

    /**
     * copy a directory If targetLocation does not exist, it will be created.
     * @param sourceLocation
     * @param targetLocation
     * @return none
     */
    public static void copyDirectory(File sourceLocation , File targetLocation)
    throws IOException {
        if (sourceLocation.isDirectory()) {
            if (!targetLocation.exists()) {
                targetLocation.mkdir();
            }

            String[] children = sourceLocation.list();
            for (int i=0; i<children.length; i++) {
                copyDirectory(new File(sourceLocation, children[i]),
                        new File(targetLocation, children[i]));
            }
        } else {

            InputStream in = new FileInputStream(sourceLocation);
            OutputStream out = new FileOutputStream(targetLocation);

            // Copy the bits from instream to outstream
            byte[] buf = new byte[1024];
            int len;
            while ((len = in.read(buf)) > 0) {
                out.write(buf, 0, len);
            }
            in.close();
            out.close();
        }
    }

	 // Deletes all files and subdirectories under dir.
	 // Returns true if all deletions were successful.
	 // If a deletion fails, the method stops attempting to delete and returns false.
	 public static boolean deleteDir(File dir) {
	     if (dir.isDirectory()) {
	         String[] children = dir.list();
	         for (int i=0; i<children.length; i++) {
	             boolean success = deleteDir(new File(dir, children[i]));
	             if (!success) {
	                 return false;
	             }
	         }
	     }

	     // The directory is now empty so delete it
	     return dir.delete();
	 }

	 public static int runBackup (ProcessExecutor processExecutor,String source,List<String> commandList)
			 throws IOException {
		 int returnValue=1;

	        // do NOT(!) store stdOut, it very often leads to:
	        // java.lang.OutOfMemoryError: Java heap space
		 	if (DO_VSS)
		 	{
				 StringBuilder stringBuilder = new StringBuilder();
				    for (String command : commandList) {
				        stringBuilder.append(command);
				        stringBuilder.append(' ');
				    }
				    //Dividir en 2
				 String script= "@ECHO off\r\n" +
					 		"REM ---- Change current drive ----\r\n" +
					 		"REM We need ssed.exe,dosdev.exe\r\n" +
					 		"REM Usage: vss.bat runfrom temp mapdrive: copydrive:\r\n" +
					 		"REM For reasons that are undocumented - but probably related to the location of\r\n" +
					 		"REM snapshot data - vshadow must be run with a local, or the snapshot source,\r\n" +
					 		"REM drive as the current drive on the command line. So we must switch to source\r\n" +
					 		"REM drive and ensure that all calls to external programs are mapped back to the\r\n" +
					 		"REM original location  - which may for instance be on a network share\r\n" +
					 		"SET runfrom="+USER_HOME+"\\.jbackpack\r\n" +
					 		"SET vss=y\r\n" +
					 		"SET TEMP=" +TEMP_DIR + "\r\n" +
					 		"SET mapdrive="+mapdrive+"\r\n" +
					 		"SET unit="+source.substring(0,2)+"\r\n" +
					 		"\r\n" +
					 		"\r\n" +
					 		"ECHO ------------------------------------VSS--------------------------------------------------\r\n" +
					 		"REM ----------\r\n" +
					 		"REM Determine Windows version WINVER 5.0=2000, 5.1=XP, 5.2=2003, 6.0=Vista, 6.1=7/2008\r\n" +
					 		"FOR /F \"tokens=2* delims=[]\" %%A IN ('VER') DO FOR /F \"tokens=2,3 delims=. \" %%B IN (\"%%A\") DO SET WINVER=%%B.%%C\r\n" +
					 		"REM Determine Windows 32-bit (x86) or 64-bit (x64) WINBIT\r\n" +
					 		"SET WINBIT=x86&&IF \"%PROCESSOR_ARCHITECTURE%\" == \"AMD64\" (SET WINBIT=x64) ELSE IF \"%PROCESSOR_ARCHITEW6432%\" == \"AMD64\" SET WINBIT=x64\r\n" +
					 		"IF %WINVER% LSS 5.1 (\r\n" +
					 		"	ECHO Sorry, timedicer cannot run under this version of Windows %WINVER%-%WINBIT%.\r\n" +
					 		"	SET el=12\r\n" +
					 		"	GOTO :endd\r\n" +
					 		")\r\n" +
					 		"REM Set VSHADOWVER appropriately for the vshadow-n-[bit].exe programs\r\n" +
					 		"IF %WINVER%==5.1 SET VSHADOWVER=xp&&SET WINBIT=x86\r\n" +
					 		"IF %WINVER%==5.2 SET VSHADOWVER=2003&&SET WINBIT=x86\r\n" +
					 		"IF %WINVER%==6.0 SET VSHADOWVER=2008\r\n" +
					 		"IF %WINVER%==6.1 SET VSHADOWVER=2008-r2\r\n" +
					 		"\r\n" +
					 		"\r\n" +
					 		"REM -------------------------------------------------------------------------------\r\n" +
					 		"	 ECHO About to check for vshadow-%VSHADOWVER%-%WINBIT%.exe\r\n" +
					 		"     SET el=0\r\n" +
					 		"	REM CALL :file_check vshadow-%VSHADOWVER%-%WINBIT%.exe http://edgylogic.com/blog/vshadow-exe-versions %el%\r\n" +
					 		"	REM IF ERRORLEVEL 1 SET el=5&&GOTO :endd\r\n" +
					 		"	 ECHO About to check for dosdev.exe\r\n" +
					 		"    REM CALL :file_check dosdev.exe http://www.ltr-data.se/files/dosdev.zip %el%\r\n" +
					 		"	REM IF ERRORLEVEL 1 SET el=5&&GOTO :endd\r\n" +
					 		"	IF %el% GEQ 1 (\r\n" +
					 		"		ECHO Backup will continue but with Volume Shadow Services disabled.\r\n" +
					 		"		SET vss=n\r\n" +
					 		"		SET el=0\r\n" +
					 		"        GOTO :endd\r\n" +
					 		"	)\r\n" +
					 		"IF /I \"%vss%\" == \"y\" (\r\n" +
					 		"	REM allowed status for shadow writers is 1 (stable) or 5 (waiting for completion) - see http://msdn.microsoft.com/en-us/library/aa384979%28VS.85%29.aspx\r\n" +
					 		"    SET VSSNOTREADY = 0\r\n" +
					 		"	\"%runfrom%\\vshadow-%VSHADOWVER%-%WINBIT%.exe\" -ws|\"%runfrom%\\ssed.exe\" -n -e \"/Status: [1|5]/p\"|\"%runfrom%\\ssed.exe\" -n \"$=\">%TEMP%\\TimeDicer-vsswriters_status.txt\r\n" +
					 		"	FOR /F \"usebackq\" %%A IN ('%TEMP%\\TimeDicer-vsswriters_status.txt') DO set VSSNOTREADY=%%~zA\r\n" +
					 		"	IF %VSSNOTREADY LEQ 0 (\r\n" +
					 		"		ECHO Volume Shadow Writer[s] not ready, aborting...\r\n" +
					 		"		SET el=3\r\n" +
					 		"		GOTO :endd\r\n" +
					 		"	)\r\n" +
					 		"	REM IF ERRORLEVEL 1 SET el=107&&GOTO :endd\r\n" +
					 		"	REM IF %quiet% == n ECHO Volume Shadow Service is available and will be used\r\n" +
					 		") ELSE (\r\n" +
					 		"	REM prevent any mapping if vss is off\r\n" +
					 		"	SET mapdrive=%intSettingsLast%\r\n" +
					 		"	ECHO Volume Shadow Service will not be used\r\n" +
					 		")\r\n" +
					 		"\r\n" +
					 		"IF /I \"%vss%\" == \"y\" (\r\n" +
					 		"SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION\r\n" +
					 		"REM ---- Tidy up before starting the volume shadowing and backup ----\r\n" +
					 		"REM delete any existing shadow copies  - there should not normally be any, but can be if a previous backup failed\r\n" +
					 		"IF /I \"%vss%\" == \"y\" (\r\n" +
					 		"	IF ERRORLEVEL 1 SET el=109&&GOTO :endd\r\n" +
					 		"	 ECHO About to delete any existing shadow copies\r\n" +
					 		"	ECHO y|\"%runfrom%\\vshadow-%VSHADOWVER%-%WINBIT%.exe\" -da>nul\r\n" +
					 		"	IF ERRORLEVEL 1 (\r\n" +
					 		"		 ECHO Error occurred: testing for administrator permissions\r\n" +
					 		"		MKDIR \"%windir%\\system32\\test\" 2>nul\r\n" +
					 		"		IF ERRORLEVEL 1 (\r\n" +
					 		"			REM not running as administrator, this is cause of failure\r\n" +
					 		"			ECHO No administrator permissions\r\n" +
					 		"			SET /A el=11\r\n" +
					 		"		) ELSE (\r\n" +
					 		"			REM running as administrator, there is a problem with vshadow\r\n" +
					 		"			RMDIR \"%windir%\\system32\\test\"\r\n" +
					 		"			SET /A el=7\r\n" +
					 		"		)\r\n" +
					 		"		GOTO :endd\r\n" +
					 		"	)\r\n" +
					 		"    ECHO Deleted any existing shadow copies\r\n" +
					 		")\r\n" +
					 		"REM ---- Do the backup ----\r\n" +
					 		"SET ACTIONERR=0\r\n" +
					 		"IF /I \"%vss%\" EQU \"y\" (\r\n" +
					 		"	ECHO Cloning ^(as %mapdrive%^) started %DATE% %TIME%\r\n" +
					 		"	ECHO.\r\n" +
					 		"	ECHO Summary ^(details follow further below^):\r\n" +
					 		")\r\n" +
					 		"	IF ERRORLEVEL 1 SET el=111&&GOTO :endd\r\n" +
					 		"	REM ---- Run vshadow, which will create shadow copy, run timedicer-action.bat, then delete shadow copy ----\r\n" +
					 		"	ECHO About to run 'timedicer-action.bat' in VSS mode\r\n" +
					 		"	SET el = 0 \r\n" +
					 		"	\"%runfrom%\\vshadow-%VSHADOWVER%-%WINBIT%.exe\" -script=%TEMP%TimeDicer-vss-setvar.cmd -exec=%1  %unit%  \r\n" +
					 		"	IF ERRORLEVEL 1 set el=1 \r\n" +
					 		"    ECHO Returned from running 'timedicer-action.bat' in VSS mode\r\n" +
					 		")\r\n" +
					 		"ENDLOCAL\r\n" +
					 		"\r\n" +
					 		":endd\r\n" +
					 		"IF %el% GEQ 1 SET ERRORLEVEL=1  \r\n";

				 String script2 = "REM ---- timedicer-action.bat script creation ----\r\n" +
				 		"SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION\r\n" +
				 		"REM map the shadow device to drive m:\r\n" +
				 		"call "+TEMP_DIR+"\\TimeDicer-vss-setvar.cmd\r\n" +
				 		USER_HOME+"\\.jbackpack\\dosdev "+mapdrive+" %SHADOW_DEVICE_1% \r\n" +
				 		"REM cycnet echo command to do backup\r\n" +
				 		"SET el=0 \r\n" +
				 		stringBuilder.toString().replace("%s","%%s")+" \r\n"+
					 		"IF ERRORLEVEL 1 set el=1\r\n" +
					 		"REM delete shadow device drive mapping\r\n" +
					 		"dir "+mapdrive+"\\ \r\n"+
					 		USER_HOME+"\\.jbackpack\\dosdev -r -d "+mapdrive+" \r\n" +
					 		"IF el GEQ 1 SET ERRORLEVEL=1 \r\n" +
					 		"ELSE ECHO OK\r\n" ;
		        Logger logger = Logger.getLogger(
		                ProcessExecutor.class.getName());
		        Level level = logger.getLevel();
		        /*
		        if ((new File(TEMP_DIR+"TimeDicer-vss-setvar.cmd" )).exists() || (new File(TEMP_DIR+"timedicer-action.bat")).exists())
		        	{
		        	LOGGER.severe("Previous backup error, close all programs and delete contents on: "+TEMP_DIR);
		        	return 1;
		        	}
		        */
		        //logger.setLevel(Level.OFF);
		        LOGGER.finest("VSS SCRIPT:\n"+script2);
		        File scriptFile = null;
		        FileWriter fileWriter = null;
		        try {
		            scriptFile = File.createTempFile("processExecutor",".bat", null);
		            fileWriter = new FileWriter(scriptFile);
		            fileWriter.write(script);
		        } finally {
		            if (fileWriter != null) {
		                fileWriter.close();
		            }
		        }
		        scriptFile.setExecutable(true);
		        File scriptFile2 = null;
		        FileWriter fileWriter2 = null;
		        try {
		            scriptFile2 = File.createTempFile("processExecutor",".bat", null);
		            fileWriter2 = new FileWriter(scriptFile2);
		            fileWriter2.write(script2);
		        } finally {
		            if (fileWriter2 != null) {
		                fileWriter2.close();
		            }
		        }
		        scriptFile2.setExecutable(true);
		        // do NOT(!) store stdOut, it very often leads to
		        // java.lang.OutOfMemoryError: Java heap space
		        returnValue = processExecutor.executeProcess(
		                true, true, scriptFile.getPath(),scriptFile2.getPath());
		        scriptFile.delete();
		        scriptFile2.delete();
		//        // restore previous log level
		        logger.setLevel(level);

		 	}
		 	else{
		        String[] commandArray = new String[commandList.size()];
		        commandArray = commandList.toArray(commandArray);
		 		returnValue = processExecutor.executeProcess(false, true, commandArray);
		 	}

		 	return returnValue;

	 }

}



