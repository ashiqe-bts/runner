local pose = require('animation')
type Body = {vertices: GPUBuffer, indices: GPUBuffer, count: number, uniform: GPUBuffer, bytes: buffer, group: GPUBindGroup}
type Scene = {canvas: GPUCanvas?, pipeline: GPUPipeline?, depth: GPUTextureView?, bodies: {Body}, time: number}
local function body(context: Context, pipeline: GPUPipeline, name: string): Body
    local blob = context:blob(name)
    assert(blob, 'Missing mesh: '..name)
    local data=blob.data
    local count=buffer.readu32(data,0)
    local indices=buffer.readu32(data,4)
    local v=buffer.create(count*56); buffer.copy(v,0,data,8,count*56)
    local ix=buffer.create(indices*2); buffer.copy(ix,0,data,8+count*56,indices*2)
    local uniform=GPUBuffer.new({size=1440,usage='uniform'})
    return {vertices=GPUBuffer.new({size=buffer.len(v),usage='vertex',data=v,immutable=true}),
        indices=GPUBuffer.new({size=buffer.len(ix),usage='index',data=ix,immutable=true}),count=indices,
        uniform=uniform, bytes=buffer.create(1440),group=GPUBindGroup.new({layout=pipeline:getBindGroupLayout(0),ubos={{slot=0,buffer=uniform}}})}
end
local function init(self: Scene, context: Context): boolean
    self.canvas=context:gpuCanvas({width=400,height=700})
    local shader=context:shader('gate')
    assert(shader)
    self.pipeline=GPUPipeline.new({vertex=shader,vertexLayout={{stride=56,attributes={
        {slot=0,format='float32x3',offset=0},{slot=1,format='float32x3',offset=12},
        {slot=2,format='float32x4',offset=24},{slot=3,format='float32x4',offset=40}}}},
        colorTargets={{format='rgba8unorm'}},depthStencil={format='depth32float',compare='less',write=true}})
    self.depth=GPUTexture.new({width=400,height=700,format='depth32float',renderTarget=true}):view()
    local pipeline=self.pipeline
    assert(pipeline)
    self.bodies={body(context,pipeline,'courier'),body(context,pipeline,'officer'),body(context,pipeline,'track'),body(context,pipeline,'pod')}
    return true
end
local function advance(self: Scene, dt: number): boolean self.time+=dt; return true end
local function draw(self: Scene, renderer: Renderer)
    if not self.canvas or not self.pipeline or not self.depth then return end
    local pass=self.canvas:beginRenderPass({color={{loadOp='clear',storeOp='store',clearColor={.025,.07,.12,1}}},
        depthStencil={view=self.depth,depthLoadOp='clear',depthStoreOp='discard',depthClearValue=1}})
    pass:setPipeline(self.pipeline)
    local eye=Vector.xyz(3,2.7,5)
    local vp=Mat4.perspective(.8,400/700,.1,180)*Mat4.lookAt(eye,Vector.xyz(0,.9,0),Vector.xyz(0,1,0))
    for i,b in self.bodies do
        vp:writeToBuffer(b.bytes,0)
        Mat4.fromTranslation(if i==1 then -.65 elseif i==2 then .65 elseif i==4 then -2 else 0,0,if i==4 then -2 else 0):writeToBuffer(b.bytes,64)
        local bones=if i<=2 then pose(self.time,1,12) else table.create(20,Mat4.identity())
        for j,m in bones do m:writeToBuffer(b.bytes,128+(j-1)*64) end
        for j,v in {.10,.70,.60,1,eye.x,eye.y,eye.z,1} do buffer.writef32(b.bytes,1408+(j-1)*4,v) end
        b.uniform:write(b.bytes)
        pass:setBindGroup(0,b.group); pass:setVertexBuffer(0,b.vertices); pass:setIndexBuffer(b.indices); pass:drawIndexed(b.count)
    end
    pass:finish()
    renderer:drawImage(self.canvas.image,ImageSampler('clamp','clamp','bilinear'),'srcOver',1)
end
return function(context: Context): Layout<Scene>
    return {canvas=nil,pipeline=nil,depth=nil,bodies={},time=0,init=init,advance=advance,draw=draw}
end
