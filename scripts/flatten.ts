import { execSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';

(async () => {
    if (process.argv.length !== 3) {
        console.log('Must specify configuration to flatten');

        process.exit(1);
    }

    const name = process.argv[2].toLowerCase();

    const config = resolve(process.cwd() + '/configs/' + name + '.config.ts');

    const license = (JSON.parse(
        readFileSync(
            resolve(process.cwd() + '/package.json'))
            .toString()
    ) as { license: string}).license;

    if (!existsSync(config)) {
        console.log('Configuration not found for: %s', name);

        process.exit(1);
    }

    const output = execSync('npx hardhat --config ' + config + ' flatten', {
        cwd: process.cwd()
    })
        .toString()
        .split('\n');

    const result: string[] = [
        '// SPDX-License-Identifier: ' + license,
        'pragma solidity ^0.8.10;',
        '',
        ''
    ];

    let previous: string;

    output.forEach(line => {
        if (!line.startsWith('// SPDX-License') && !line.startsWith('pragma solidity')) {
            if (line === previous) {
                return;
            }

            previous = line;

            result.push(line);
        }
    });

    console.log(result.join('\n'));
})();
