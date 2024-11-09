import esbuild from 'esbuild';
import { sassPlugin } from 'esbuild-sass-plugin';
import manifestPlugin from 'esbuild-plugin-manifest';
import ImportGlobPlugin from 'esbuild-plugin-import-glob';

const env = (process.env['NODE_ENV'] ?? 'development').toLowerCase();
const production = env === 'production';
const watch = !production && process.argv.slice(2).includes('--watch');

const packages = [
  'application'
];

const options = {
  entryPoints: [
    ...packages.flatMap((name) => {
      return [
        {
          out: name,
          in: `source/assets/${name}.js`
        },
        {
          out: name,
          in: `source/assets/${name}.scss`
        },
      ];
    }),
    'source/assets/images.js'
  ],
  entryNames: '[name]-[hash]',
  outdir: 'tmp/assets',
  bundle: true,
  sourcemap: !production,
  publicPath: '/assets',
  metafile: true,
  logLevel: 'info',
  minify: production,
  loader: {
    '.jpg': 'file',
    '.png': 'file',
    '.woff2': 'file',
  },
  plugins: [
    manifestPlugin({
      generate(files) {
        const transform = (string) => {
          const outdir = 'tmp/assets';
          const expression = new RegExp(`^${outdir}/+`);

          return string.replace(expression, '');
        }

        return Object.entries(files)
          .reduce((files, keyValue) => {
            const [key, value] = keyValue.map(transform);

            return {
              ...files,
              [key]: value
            }
          }, {})
      }
    }),
    ImportGlobPlugin.default(),
    sassPlugin(),
  ]
};


if (watch) {
  const context = await esbuild.context(options);
  await context.watch();
}
else {
  await esbuild.build({
    ...options,
  });
}
