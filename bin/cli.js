#! /usr/bin/env node

var program = require('commander'),
    inquirer = require('inquirer'),
    fs = require('fs'),
    exec = require('child_process').exec,
    debug = require('debug')('openframe:cli'),
    p = require('../package.json'),
    version = p.version,
    config = require('../src/config'),
    frame = require('../src/frame'),
    user = require('../src/user'),
    rest = require('../src/rest'),
    frame_controller = require('../src/controller'),
    proc_man = require('../src/process-manager'),
    initializers;

program
    .version(version)
    .option('-r, --reset', 'Reset this frame. Erases current frame data, and registers this as a new frame.')
    .option('-s, --stop', 'Stop this frame but keep all data.')
    .option('-i, --install [extension]', 'Install an extension. The argument should be in the npm package name format, e.g. "openframe-image" or "openframe-image@^0.1.0"')
    .option('-u, --uninstall [extension]', 'Uninstall an extension. The argument should be the npm package name, e.g. "openframe-image"')
    .arguments('[username] [password] [framename]')
    .parse(process.argv);

// load config, frame, and user from local dot files
initializers = [
    config.load(),
    frame.load(),
    user.load()
];

Promise.all(initializers)
    .then(rest.init)
    .then(function() {
        debug(config.ofrc);
        debug(frame.state);
        debug(user.state);

        if (program.reset) {
            reset()
                .then(processArgs)
                .catch(debug);
        } else {
            processArgs();
        }

    }).catch(function(err) {
        debug(err);
    });


function processArgs() {
    debug('processArgs');

    if (program.stop) {
        exec("sudo service of-framectrl stop", (error, stdout, stderr) => {
            if (error) {
                debug(`error: ${error.message}`);
                return;
            }
            if (stderr) {
                debug(`stderr: ${stderr}`);
                return;
            }
            debug(`stdout: ${stdout}`);
        });
        console.log('Service of-framectrl stopped');
        process.exit(0);
    }

    // if username was passed, set it
    user.state.username = program.username || user.state.username;

    // if password was passed, set it
    user.state.password = program.password || user.state.password;

    // if framename passed, set it
    frame.state.name = program.framename || frame.state.name;

    debug(user.state, frame.state);

    var questions = [];

    if (!user.state.username) {
        // ask for user
        questions.push({
            name: 'username',
            message: 'Enter your Openframe username:'
        });
    }

    if (!user.state.password) {
        // ask for pass
        questions.push({
            name: 'password',
            type: 'password',
            message: 'Enter your Openframe password:'
        });
    }

    if (!frame.state.name) {
        // ask frame name
        questions.push({
            name: 'frame_name',
            message: 'Enter a name for this Frame:'
        });
    }

    if (config.ofrc.autoboot === undefined) {
        // ask frame name
        questions.push({
            name: 'autoboot',
            message: 'Do you want to boot openframe on startup?:',
            type: 'confirm'
        });
    }

    if (questions.length) {
        inquirer.prompt(questions, function(answers) {
            saveAnswers(answers)
                .then(console.log('Settings have been stored'))
                .then(init(true));
        });
    } else {
        init(false);
    }
}

/**
 * Reset the frame. This means:
 * - delete current frame state
 * - delete current user state
 *
 * @return {Promise} A promise resolving when the user and frame have been reset
 */
function reset() {
    debug('Reseting frame.');
    return new Promise(function(resolve, reject) {
        user.state = {};
        frame.state = {};
        delete config.ofrc.autoboot;
        user.save()
            .then(frame.persistStateToFile)
            .then(config.save)
            .then(resolve)
            .catch(reject);
    });
}

/**
 * Save the answers from the prompt to .ofrc file.
 * @param  {Object} answers
 * @return {Promise}
 */
function saveAnswers(answers) {
    if (answers) {
        if (answers.username) {
            user.state.username = answers.username;
        }
        if (answers.password) {
            user.state.password = answers.password;
        }
        if (answers.frame_name) {
            frame.state.name = answers.frame_name;
            // frame.state.id = 0;
        }
        if (answers.autoboot) {
            enableAutoboot();
        } else {
            disableAutoboot();
        }
        config.ofrc.autoboot = answers.autoboot;
    }

    return Promise.all([config.save(), user.save(), frame.persistStateToFile()]);
}

function enableAutoboot() {
    debug('----->>> Enable Autoboot');

    exec("sudo systemctl enable of-framectrl.service", (error, stdout, stderr) => {
        if (error) {
            debug(`error: ${error.message}`);
            return;
        }
        if (stderr) {
            debug(`stderr: ${stderr}`);
            return;
        }
        debug(`stdout: ${stdout}`);
    });
}

function disableAutoboot() {
    debug('----->>> Disable Autoboot');
    exec("sudo systemctl disable of-framectrl.service", (error, stdout, stderr) => {
        if (error) {
            debug(`error: ${error.message}`);
            return;
        }
        if (stderr) {
            debug(`stderr: ${stderr}`);
            return;
        }
        debug(`stdout: ${stdout}`);
    });
}

/**
 * Start up the frame
 */
function init(restart) {
    // if we've gotten here, presumably we have a user/pass
    if (program.install) {
        console.log('\n');
        console.log('[o]   Installing ' + program.install + ' extension...');
        console.log('\n');
        frame_controller.installExtension(program.install);

    } else if (program.uninstall) {
        console.log('\n');
        console.log('[o]   Uninstalling ' + program.uninstall + ' extension...');
        console.log('\n');
        frame_controller.uninstallExtension(program.uninstall);

    } else if (restart) {
        exec("sudo service of-framectrl restart", (error, stdout, stderr) => {
            if (error) {
                debug(`error: ${error.message}`);
                return;
            }
            if (stderr) {
                debug(`stderr: ${stderr}`);
                return;
            }
            debug(`stdout: ${stdout}`);
        });
        console.log('Service of-framectrl (re)started');

    } else if (! process.env.SERVICE) {
        // This call is coming from the command line, so just start the service
        exec("sudo service of-framectrl start", (error, stdout, stderr) => {
            if (error) {
                debug(`error: ${error.message}`);
                return;
            }
            if (stderr) {
                debug(`stderr: ${stderr}`);
                return;
            }
            debug(`stdout: ${stdout}`);
        });
        console.log('Service of-framectrl started');

    } else {
        // This call is coming from the service unit, so start the actual executable
        debug('Initializing Frame Controller');
        frame_controller.init();
    }
}
