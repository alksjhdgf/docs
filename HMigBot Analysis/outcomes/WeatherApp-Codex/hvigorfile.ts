// @ts-nocheck – Template file, only used when copied into a project directory
import { appTasks } from '@ohos/hvigor-ohos-plugin';
import { turboTransProtobufPlugin } from '@hadss/turbo-trans-protobuf-plugin';

export default {
  system: appTasks /* Built-in plugin of Hvigor. It cannot be modified. */,
  plugins: [turboTransProtobufPlugin({
    saveDir: 'src/main/ets/protobuf', scanDir: ['protofile'], sendable: false
  })],
};
