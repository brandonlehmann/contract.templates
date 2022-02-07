import { execSync } from 'child_process';
import { readdirSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { resolve } from 'path';
import Logger from '@turtlepay/logger';

(async () => {
    Logger.info('Running prettier on all files...');

    execSync('yarn fix-style', {
        cwd: process.cwd()
    });

    let contracts = readdirSync(resolve(process.cwd() + '/contracts'))
        .filter(file => !file.includes('interfaces') && !file.includes('libraries'));

    if (process.argv.length === 3) {
        const name = process.argv[2];

        contracts = contracts.filter(elem => elem.includes(name));
    }

    if (!existsSync(resolve(process.cwd() + '/compiled'))) {
        mkdirSync(resolve(process.cwd() + '/compiled/'));
    }

    if (!existsSync(resolve(process.cwd() + '/configs'))) {
        mkdirSync(resolve(process.cwd() + '/configs/'));
    }

    for (const contract of contracts) {
        const target = resolve(process.cwd() + '/compiled/' + contract + '.sol');
        const configTarget = resolve(process.cwd() + '/configs/' + contract + '.config.ts');

        const config: string[] = [
            'import config from \'../hardhat.config\';',
            'import { resolve } from \'path\';',
            '',
            'config.paths = {',
            `    sources: resolve(process.cwd() + '/contracts/${contract}'),`,
            '    root: resolve(process.cwd())',
            '};',
            '',
            'export default config;',
            ''
        ];

        writeFileSync(configTarget, config.join('\n'));

        Logger.info('Generated Hardhat Configuration for: %s', contract);

        const result = execSync('ts-node scripts/flatten.ts ' + contract, {
            cwd: process.cwd()
        });

        writeFileSync(target, result);

        Logger.info('Compiled & Flattened: %s', contract);
    }

    execSync('prettier --write ./compiled/*.sol', {
        cwd: process.cwd()
    });

    Logger.info('Prettied all flattened contracts');
})();
