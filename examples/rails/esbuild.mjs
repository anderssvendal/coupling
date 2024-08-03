import esbuild from 'esbuild';
import { sassPlugin } from 'esbuild-sass-plugin';
import manifestPlugin from 'esbuild-plugin-manifest';

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
          in: `app/assets/${name}.js`
        },
        {
          out: name,
          in: `app/assets/${name}.scss`
        },
      ];
    })
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
      shortNames: true
    }),
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
